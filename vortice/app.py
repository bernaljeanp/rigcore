"""Punto de entrada de Vórtice: expone el hardware a la interfaz QML."""

from __future__ import annotations

import os
import sys
import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QFontDatabase, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from . import hardware

HERE = Path(__file__).resolve().parent
HISTORY = 90  # segundos de historial para las gráficas


class Backend(QObject):
    statsChanged = Signal()
    profileChanged = Signal()
    _profileReady = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self._caps = hardware.detect()
        self.sampler = hardware.Sampler(self._caps)
        self._stats: dict = {}
        self._hist = {"cpu": [], "gpu": []}
        self._profile = hardware.get_profile() or ""
        self._profileReady.connect(self._apply_profile)

        self.timer = QTimer(self, interval=1000, timeout=self._tick)
        self.timer.start()
        self.sampler.sample()  # primera muestra para el delta de CPU
        QTimer.singleShot(250, self._tick)
        # El perfil puede cambiarse desde fuera (KDE, modo-juego-auto).
        self.ptimer = QTimer(self, interval=3000, timeout=self._poll_profile)
        self.ptimer.start()
        self._init_helper()

    # ---- datos ------------------------------------------------------------
    def _tick(self) -> None:
        s = self.sampler.sample()
        for key in ("cpu", "gpu"):
            h = self._hist[key]
            h.append(s[key].get("temp"))  # None = sin lectura (p. ej. GPU dormida)
            del h[:-HISTORY]
        s["history"] = {k: list(v) for k, v in self._hist.items()}
        self._stats = s
        self.statsChanged.emit()

    def _poll_profile(self) -> None:
        threading.Thread(
            target=lambda: self._profileReady.emit(hardware.get_profile() or ""),
            daemon=True,
        ).start()

    def _apply_profile(self, p: str) -> None:
        if p and p != self._profile:
            self._profile = p
            self.profileChanged.emit()

    # ---- propiedades para QML --------------------------------------------
    @Property("QVariantMap", notify=statsChanged)
    def stats(self) -> dict:
        return self._stats

    @Property("QVariantMap", constant=True)
    def caps(self) -> dict:  # type: ignore[override]
        c = self._caps
        return {
            "vendor": c.vendor_driver,
            "cpuName": c.cpu_name,
            "gpuName": c.gpu_name or "Sin gráfica",
            "gpuKind": c.gpu_kind,
            "gpuDiscrete": c.gpu_discrete,
            "profileManager": c.profile_manager,
            "hasBattery": bool(c.battery),
            "fanCount": len(c.fans),
            "fanBoost": any(f.boost_path for f in c.fans),
            "profiles": c.power_profiles_dbus,
            "chargeLimit": bool(c.charge_threshold),
            "firmwareBattery": c.firmware_battery,
            "hostname": os.uname().nodename,
        }

    @Property(str, notify=profileChanged)
    def profile(self) -> str:
        return self._profile

    # ---- servicio privilegiado (ventiladores y batería) --------------------
    helperChanged = Signal()
    notify = Signal(str, bool)  # mensaje, éxito
    _helperReady = Signal("QVariantMap")

    def _init_helper(self) -> None:
        self._helper: dict = {"available": False}
        self._helperReady.connect(self._apply_helper)
        self.htimer = QTimer(self, interval=5000, timeout=self.refreshHelper)
        self.htimer.start()
        self.refreshHelper()

    def _apply_helper(self, st: dict) -> None:
        self._helper = st
        self.helperChanged.emit()

    @Slot()
    def refreshHelper(self) -> None:
        def work() -> None:
            st = hardware.helper_state()
            self._helperReady.emit({"available": True, **st} if st else {"available": False})

        threading.Thread(target=work, daemon=True).start()

    @Property("QVariantMap", notify=helperChanged)
    def helper(self) -> dict:
        return self._helper

    def _helper_write(self, method: str, sig: str, args: tuple, ok_msg: str) -> None:
        def work() -> None:
            ok, err = hardware.helper_call(method, sig, *args)
            self.notify.emit(ok_msg if ok else f"No se pudo aplicar: {err}", ok)
            self.refreshHelper()

        threading.Thread(target=work, daemon=True).start()

    @Slot(int, int)
    def setFanBoost(self, index: int, value: int) -> None:
        pct = round(value / 255 * 100)
        self._helper_write("SetFanBoost", "uu", (index, value),
                           f"Boost del ventilador al {pct} %" if value else "Ventilador en automático")

    @Slot(str, int, int)
    def setCharge(self, mode: str, start: int, stop: int) -> None:
        self._helper_write("SetCharge", "suu", (mode, start, stop), "Configuración de carga aplicada")

    @Slot(bool)
    def setVisible(self, visible: bool) -> None:
        """Minimizada: menos lecturas (cada 5 s) y nada que animar."""
        self.timer.setInterval(1000 if visible else 5000)
        self.htimer.setInterval(5000 if visible else 30000)

    @Slot(str)
    def setProfile(self, name: str) -> None:
        old, self._profile = self._profile, name
        self.profileChanged.emit()  # respuesta inmediata en la interfaz

        def work() -> None:
            ok = hardware.set_profile(name)
            self._profileReady.emit(name if ok else old)

        threading.Thread(target=work, daemon=True).start()


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Vórtice")
    app.setDesktopFileName("vortice")
    app.setWindowIcon(QIcon(str(HERE / "qml" / "icon.svg")))

    for f in ("Inter.ttf", "SpaceGrotesk.ttf", "JetBrainsMono.ttf"):
        QFontDatabase.addApplicationFont(str(HERE / "fonts" / f))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("hw", backend)
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1

    # Desarrollo: VORTICE_SHOT=ruta.png [VORTICE_SHOT_DELAY=s] captura y sale.
    shot = os.environ.get("VORTICE_SHOT")
    if shot:
        from PySide6.QtQuick import QQuickWindow  # noqa: F401  (tipa la ventana)

        win = engine.rootObjects()[0]

        def grab() -> None:
            win.grabWindow().save(shot)
            app.quit()

        QTimer.singleShot(int(float(os.environ.get("VORTICE_SHOT_DELAY", "3")) * 1000), grab)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
