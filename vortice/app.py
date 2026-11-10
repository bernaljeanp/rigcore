"""Punto de entrada de Vórtice: expone el hardware a la interfaz QML."""

from __future__ import annotations

import json
import os
import sys
import threading
import time
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QFontDatabase, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from . import games, hardware, lights

HERE = Path(__file__).resolve().parent
HISTORY = 90  # segundos de historial para las gráficas


class Backend(QObject):
    statsChanged = Signal()
    profileChanged = Signal()
    _profileReady = Signal(str)
    detailsChanged = Signal()
    _detailsReady = Signal("QVariantMap")

    def __init__(self) -> None:
        super().__init__()
        self._caps = hardware.detect()
        self.sampler = hardware.Sampler(self._caps)
        self._stats: dict = {}
        self._hist = {"cpu": [], "gpu": []}
        self._profile = hardware.get_profile() or ""
        self._profileReady.connect(self._apply_profile)
        self._details: dict = {}
        self._detailsReady.connect(self._apply_details)

        self.timer = QTimer(self, interval=1000, timeout=self._tick)
        self.timer.start()
        self.sampler.sample()  # primera muestra para el delta de CPU
        QTimer.singleShot(250, self._tick)
        # El perfil puede cambiarse desde fuera (KDE, modo-juego-auto).
        self.ptimer = QTimer(self, interval=3000, timeout=self._poll_profile)
        self.ptimer.start()
        self._poll_profile()
        self._init_helper()
        self._init_games()
        self._init_lights()

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
        def work() -> None:
            self._profileReady.emit(hardware.get_profile() or "")
            self._detailsReady.emit(hardware.get_profile_details(self._caps))

        threading.Thread(target=work, daemon=True).start()

    def _apply_details(self, d: dict) -> None:
        if d != self._details:
            self._details = d
            self.detailsChanged.emit()

    @Property("QVariantMap", notify=detailsChanged)
    def profileDetails(self) -> dict:
        return self._details

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
            "model": c.model,
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

    # ---- perfiles por juego -------------------------------------------------
    gamesChanged = Signal()
    agentChanged = Signal()
    _gamesReady = Signal("QVariantList", "QVariantList")

    def _init_games(self) -> None:
        self._gcfg = games.load_config()
        self._library: list = []
        self._conflicts: list = []
        self._agent: dict = {}
        self._gamesReady.connect(self._apply_games)
        self.refreshGames()
        self.atimer = QTimer(self, interval=3000, timeout=self._poll_agent)
        self.atimer.start()
        self._poll_agent()

    @Slot()
    def refreshGames(self) -> None:
        def work() -> None:
            lib = games.steam_games() + games.process_games(self._gcfg)
            self._gamesReady.emit(lib, games.conflicting_services())

        threading.Thread(target=work, daemon=True).start()

    def _apply_games(self, lib: list, conflicts: list) -> None:
        self._library, self._conflicts = lib, conflicts
        self.gamesChanged.emit()
        self.agentChanged.emit()

    def _poll_agent(self) -> None:
        st = games.agent_state()
        alive = bool(st) and time.time() - st.get("updated", 0) < 45
        info = {"alive": alive, **st}
        if info != self._agent:
            self._agent = info
            self.agentChanged.emit()

    def _save_games(self) -> None:
        games.save_config(self._gcfg)
        self.gamesChanged.emit()

    @Property("QVariantList", notify=gamesChanged)
    def gamesList(self) -> list:
        out = []
        for g in self._library:
            prof = self._gcfg["games"].get(g["id"])
            out.append({**g, "mode": prof.get("mode") if prof else "",
                        "boost": int(prof.get("boost") or 0) if prof else 0})
        return out

    @Property("QVariantMap", notify=gamesChanged)
    def gamesConfig(self) -> dict:
        d = self._gcfg["default"]
        return {"enabled": self._gcfg["enabled"], "acOnly": self._gcfg["acOnly"],
                "defaultMode": d.get("mode", "performance"), "defaultBoost": int(d.get("boost") or 0)}

    @Property("QVariantMap", notify=agentChanged)
    def agentInfo(self) -> dict:
        return {**self._agent, "conflicts": self._conflicts}

    @Slot(str, str)
    def setGameMode(self, gid: str, mode: str) -> None:
        """mode: "" = usar el predeterminado, "none" = sin cambios, o un modo."""
        if not mode:
            self._gcfg["games"].pop(gid, None)
        else:
            self._gcfg["games"].setdefault(gid, {"boost": 0})["mode"] = mode
        self._save_games()

    @Slot(str, int)
    def setGameBoost(self, gid: str, value: int) -> None:
        entry = self._gcfg["games"].setdefault(gid, {"mode": self._gcfg["default"].get("mode", "performance")})
        entry["boost"] = max(0, min(255, value))
        self._save_games()

    @Slot(str, int)
    def setDefault(self, mode: str, boost: int) -> None:
        self._gcfg["default"] = {"mode": mode, "boost": max(0, min(255, boost))}
        self._save_games()

    @Slot(bool)
    def setGamesEnabled(self, on: bool) -> None:
        self._gcfg["enabled"] = on
        self._save_games()
        if on and not self._agent.get("alive"):
            self.installAgent()

    @Slot(bool)
    def setAcOnly(self, on: bool) -> None:
        self._gcfg["acOnly"] = on
        self._save_games()

    @Slot(str)
    def addProcess(self, name: str) -> None:
        name = name.strip()[:15]  # /proc/PID/comm se trunca a 15 caracteres
        if name:
            self._gcfg["processes"][name] = games.KNOWN_PROCESSES.get(name, (name,))[0]
            self._save_games()
            self.refreshGames()

    @Slot(str)
    def removeProcess(self, gid: str) -> None:
        if gid.startswith("proc:"):
            self._gcfg["processes"].pop(gid[5:], None)
            self._gcfg["games"].pop(gid, None)
            self._save_games()
            self.refreshGames()

    @Slot()
    def installAgent(self) -> None:
        def work() -> None:
            ok, out = games.install_agent()
            self.notify.emit("Agente de juegos activo" if ok else f"No se pudo activar el agente: {out}", ok)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def disableConflict(self, unit: str) -> None:
        def work() -> None:
            ok, out = games.disable_service(unit)
            self.notify.emit(f"{unit} desactivado" if ok else f"No se pudo desactivar: {out}", ok)
            self.refreshGames()

        threading.Thread(target=work, daemon=True).start()

    # ---- luces ---------------------------------------------------------------
    lightsChanged = Signal()
    LIGHTS_CFG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                              "vortice", "lights.json")

    def _init_lights(self) -> None:
        self._ctrl = lights.find_controller()
        self._lights = {"effect": "static", "color": "FFFFFF", "brightness": 100}
        try:
            with open(self.LIGHTS_CFG) as f:
                d = json.load(f)
            lights.validate(d["effect"], d["color"], d["brightness"])
            self._lights = d
        except (OSError, ValueError, KeyError, TypeError):
            pass
        self._lights_pending = None
        self._lights_cv = threading.Condition()
        threading.Thread(target=self._lights_worker, daemon=True).start()
        self.helperChanged.connect(self.lightsChanged)

    def _lights_worker(self) -> None:
        """Aplica solo el ajuste más reciente: arrastrar el color no satura el USB."""
        while True:
            with self._lights_cv:
                while self._lights_pending is None:
                    self._lights_cv.wait()
                eff, col, bri = self._lights_pending
                self._lights_pending = None
            if self._helper.get("available"):
                ok, err = hardware.helper_call("SetLights", "ssu", eff, col, bri)
            else:
                try:
                    lights.apply(eff, col, bri, self._ctrl)
                    ok, err = True, None
                except (OSError, RuntimeError, ValueError) as e:
                    ok, err = False, str(e)
            if not ok:
                self.notify.emit(f"Luces: {err}", False)

    @Property("QVariantMap", notify=lightsChanged)
    def lightsState(self) -> dict:
        via = "service" if self._helper.get("available") else (
            "direct" if lights.writable(self._ctrl) else "none")
        return {"available": bool(self._ctrl), "device": self._ctrl["name"] if self._ctrl else "",
                "path": self._ctrl["path"] if self._ctrl else "", "via": via,
                "aurora": ["%02X%02X%02X" % c for c in lights.AURORA], **self._lights}

    @Slot(str, str, int)
    def setLights(self, effect: str, color: str, brightness: int) -> None:
        try:
            lights.validate(effect, color, brightness)
        except ValueError as e:
            self.notify.emit(str(e), False)
            return
        self._lights = {"effect": effect, "color": color.upper(), "brightness": int(brightness)}
        os.makedirs(os.path.dirname(self.LIGHTS_CFG), exist_ok=True)
        with open(self.LIGHTS_CFG, "w") as f:
            json.dump(self._lights, f)
        self.lightsChanged.emit()
        with self._lights_cv:
            self._lights_pending = (effect, color.upper(), int(brightness))
            self._lights_cv.notify()

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

    for f in sorted((HERE / "fonts").glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("hw", backend)
    engine.rootContext().setContextProperty("startPage", int(os.environ.get("VORTICE_PAGE", "0")))
    engine.rootContext().setContextProperty("startGame", os.environ.get("VORTICE_GAME", ""))
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
