"""Bandeja del sistema, instancia única y ventana bajo demanda.

En la bandeja, Vórtice funciona sin el motor QML (la parte cara): solo el
backend con lecturas espaciadas. La ventana se crea al abrirla y se destruye
al cerrarla para devolver la memoria.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QObject, QProcess, QTimer
from PySide6.QtGui import QAction, QActionGroup, QColor, QIcon
from PySide6.QtNetwork import QLocalServer
from PySide6.QtWidgets import QMenu, QSystemTrayIcon

HERE = Path(__file__).resolve().parent
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "vortice"
SOCKET = RUNTIME / "app.sock"        # proceso de la bandeja
GUI_SOCKET = RUNTIME / "gui.sock"    # proceso de la ventana
AUTOSTART = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "autostart" / "vortice.desktop"

MODES = [("power-saver", "Silencioso"), ("balanced", "Equilibrado"), ("performance", "Rendimiento")]
EFFECTS = [("static", "Fijo"), ("breathe", "Respirar"), ("aurora", "Aurora"), ("off", "Apagado")]
LIGHT_LEVELS = [100, 40, 0]          # ciclo de la tecla de luces (como en Zenit)


class WindowController(QObject):
    """La ventana vive en su propio proceso: al cerrarla, el sistema recupera
    toda su memoria (motor QML, driver gráfico), algo imposible dentro del mismo
    proceso. La bandeja solo la lanza o la trae al frente."""

    def __init__(self) -> None:
        super().__init__()
        self.proc: QProcess | None = None

    def running(self) -> bool:
        return self.proc is not None and self.proc.state() != QProcess.ProcessState.NotRunning

    def show(self, page: int | None = None) -> None:
        if self.running() or GUI_SOCKET.exists():
            if send_to_running("raise", sock=GUI_SOCKET) is not None:
                return
        self.proc = QProcess(self)
        args = ["-m", "vortice.app", "--ventana"]
        if page is not None:
            args += ["--pagina", str(page)]
        self.proc.setWorkingDirectory(str(HERE.parent))
        self.proc.start(sys.executable, args)

    def toggle(self) -> None:
        if self.running():
            send_to_running("close", sock=GUI_SOCKET)
        else:
            self.show()


def _ini_value(path: Path, group: str, key: str) -> str | None:
    """Lee una clave de un archivo estilo INI de KDE sin dependencias."""
    try:
        cur = None
        for line in path.read_text(errors="ignore").splitlines():
            line = line.strip()
            if line.startswith("[") and line.endswith("]"):
                cur = line[1:-1]
            elif cur == group and line.startswith(key + "="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return None


CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")))
WATCHED = [CONFIG_DIR / "plasmarc", CONFIG_DIR / "kdeglobals"]


def panel_text_color() -> QColor:
    """Color del texto del panel: el del tema de Plasma activo; si el tema sigue al
    esquema de color, el del esquema (kdeglobals)."""
    theme = _ini_value(CONFIG_DIR / "plasmarc", "Theme", "name") or "default"
    candidates = [Path(os.path.expanduser(f"~/.local/share/plasma/desktoptheme/{theme}/colors")),
                  Path(f"/usr/share/plasma/desktoptheme/{theme}/colors"),
                  CONFIG_DIR / "kdeglobals"]
    for c in candidates:
        v = _ini_value(c, "Colors:Window", "ForegroundNormal")
        if v:
            try:
                r, g, b = (int(x) for x in v.split(",")[:3])
                return QColor(r, g, b)
            except ValueError:
                continue
    from PySide6.QtWidgets import QApplication
    return QApplication.palette().windowText().color()


def launcher() -> str:
    """Orden para lanzar Vórtice: el script del repositorio si se ejecuta desde
    el código fuente; si no, el comando instalado."""
    import shutil

    dev = HERE.parent / "vortice.sh"
    if dev.exists():
        return str(dev.resolve())
    return shutil.which("vortice") or "vortice"


def tray_icon() -> QIcon:
    """Icono monocromo pintado con el color del panel, a varios tamaños.
    (Se pinta aquí en vez de depender de que Plasma lo recoloree desde su caché.)"""
    from PySide6.QtCore import QByteArray, QRectF, Qt
    from PySide6.QtGui import QPainter, QPixmap
    from PySide6.QtSvg import QSvgRenderer

    svg = (HERE / "qml" / "icon-symbolic.svg").read_text().replace("#232629", panel_text_color().name())
    renderer = QSvgRenderer(QByteArray(svg.encode()))
    icon = QIcon()
    for size in (16, 22, 24, 32, 44, 48, 64):
        pm = QPixmap(size, size)
        pm.fill(Qt.GlobalColor.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        renderer.render(p, QRectF(0, 0, size, size))
        p.end()
        icon.addPixmap(pm)
    return icon


class Tray(QObject):
    def __init__(self, backend, windows: WindowController) -> None:
        super().__init__()
        self.b = backend
        self.windows = windows
        self.icon = QSystemTrayIcon(tray_icon())
        self.icon.setToolTip("Vórtice")
        self.icon.activated.connect(self._activated)
        # Si cambias el tema de Plasma o el esquema de color, el icono se repinta.
        self.watcher = QFileSystemWatcher([str(p) for p in WATCHED if p.exists()] + [str(CONFIG_DIR)])
        self._repaint = QTimer(self, singleShot=True, interval=400,
                               timeout=lambda: self.icon.setIcon(tray_icon()))
        self.watcher.fileChanged.connect(lambda *_: self._on_theme_file())
        self.watcher.directoryChanged.connect(lambda *_: self._on_theme_file())

        self.menu = QMenu()
        self.status = self.menu.addAction("")
        self.status.setEnabled(False)
        self.menu.addSeparator()

        self.mode_group = QActionGroup(self)
        self.mode_actions = {}
        for mid, name in MODES:
            a = self.menu.addAction(name)
            a.setCheckable(True)
            a.triggered.connect(lambda _=False, m=mid: self.b.setProfile(m))
            self.mode_group.addAction(a)
            self.mode_actions[mid] = a

        self.menu.addSeparator()
        self.lights_menu = self.menu.addMenu("Luces")
        self.fx_group = QActionGroup(self)
        self.fx_actions = {}
        for fid, name in EFFECTS:
            a = self.lights_menu.addAction(name)
            a.setCheckable(True)
            a.triggered.connect(lambda _=False, f=fid: self._set_effect(f))
            self.fx_group.addAction(a)
            self.fx_actions[fid] = a
        self.lights_menu.addSeparator()
        for level in (100, 60, 30):
            a = self.lights_menu.addAction(f"Brillo {level} %")
            a.triggered.connect(lambda _=False, v=level: self._set_brightness(v))

        self.stealth_action = self.menu.addAction("Sigilo")
        self.stealth_action.setCheckable(True)
        self.stealth_action.triggered.connect(lambda: run_action(self.b, self.windows, "stealth"))

        self.games_action = self.menu.addAction("Perfiles por juego automáticos")
        self.games_action.setCheckable(True)
        self.games_action.triggered.connect(lambda on: self.b.setGamesEnabled(on))

        self.menu.addSeparator()
        self.autostart_action = self.menu.addAction("Iniciar con la sesión")
        self.autostart_action.setCheckable(True)
        self.autostart_action.triggered.connect(set_autostart)
        self.menu.addAction("Abrir Vórtice").triggered.connect(lambda: self.windows.show())
        self.menu.addAction("Salir").triggered.connect(self._quit)

        self.menu.aboutToShow.connect(self.refresh)
        self.icon.setContextMenu(self.menu)
        self.b.statsChanged.connect(self._tooltip)
        # Los avisos (teclas F6/F7/F9, errores) salen como notificación del sistema.
        self.b.notify.connect(lambda msg, ok: self.icon.showMessage(
            "Vórtice", msg, QSystemTrayIcon.MessageIcon.Information if ok else QSystemTrayIcon.MessageIcon.Warning, 2500))
        self.refresh()
        self.icon.show()
        if install_key_shortcuts():
            apply_key_shortcuts()

    def _on_theme_file(self) -> None:
        # KDE guarda reescribiendo el archivo: hay que volver a vigilarlo.
        for p in WATCHED:
            if p.exists() and str(p) not in self.watcher.files():
                self.watcher.addPath(str(p))
        self._repaint.start()

    # ---- estado ---------------------------------------------------------------
    def _temps(self) -> str:
        st = self.b.stats or {}
        cpu = (st.get("cpu") or {}).get("temp")
        gpu = st.get("gpu") or {}
        parts = []
        if cpu is not None:
            parts.append(f"CPU {cpu:.0f} °C")
        if gpu.get("asleep"):
            parts.append("GPU en reposo")
        elif gpu.get("temp") is not None:
            parts.append(f"GPU {gpu['temp']:.0f} °C")
        return " · ".join(parts) or "Vórtice"

    def _tooltip(self) -> None:
        self.icon.setToolTip(f"Vórtice\n{self._temps()}")

    def refresh(self) -> None:
        self.status.setText(self._temps())
        profiles = bool(self.b.caps.get("profiles"))
        for mid, a in self.mode_actions.items():
            a.setEnabled(profiles)
            a.setChecked(self.b.profile == mid)
        ls = self.b.lightsState
        self.lights_menu.setEnabled(bool(ls.get("available")) and ls.get("via") != "none")
        supported = ls.get("effects") or [f for f, _ in EFFECTS]
        for fid, a in self.fx_actions.items():
            a.setVisible(fid in supported)
            a.setChecked(ls.get("effect") == fid)
        self.stealth_action.setChecked(bool(getattr(self.b, "_stealth", None)))
        self.games_action.setChecked(bool(self.b.gamesConfig.get("enabled")))
        self.autostart_action.setChecked(AUTOSTART.exists())

    # ---- acciones -----------------------------------------------------------
    def _activated(self, reason) -> None:
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.windows.toggle()

    def _set_effect(self, effect: str) -> None:
        ls = self.b.lightsState
        bri = ls.get("brightness", 100) or (0 if effect == "off" else 100)
        self.b.setLights(effect, ls.get("color", "FFFFFF"), bri)

    def _set_brightness(self, level: int) -> None:
        ls = self.b.lightsState
        effect = ls.get("effect", "static")
        self.b.setLights("static" if effect == "off" else effect, ls.get("color", "FFFFFF"), level)

    def _quit(self) -> None:
        self.icon.hide()
        from PySide6.QtWidgets import QApplication
        QApplication.quit()


# ---- acciones rápidas (teclas F6 / F9, línea de órdenes) -----------------------

def run_action(backend, windows: WindowController | None, action: str) -> str:
    """Ejecuta una acción en la instancia en marcha. Devuelve un texto breve."""
    if action == "show":
        if windows:
            windows.show()
        return "ok"
    if action == "hide":
        send_to_running("close", sock=GUI_SOCKET)
        return "ok"
    if action == "boost":
        # Alterna Rendimiento <-> el modo que había antes.
        cur = backend.profile
        if cur == "performance":
            target = getattr(backend, "_before_boost", None) or "balanced"
        else:
            backend._before_boost = cur
            target = "performance"
        backend.setProfile(target)
        backend.notify.emit(f"Modo {dict(MODES).get(target, target)}", True)
        return target
    if action == "stealth":
        # Sigilo (tecla F7, como en Zenit): Silencioso + luces tenues; otra pulsación lo deshace.
        saved = getattr(backend, "_stealth", None)
        ls = backend.lightsState
        if saved:
            backend._stealth = None
            backend.setProfile(saved["profile"])
            if ls.get("available") and ls.get("via") != "none":
                backend.setLights(*saved["lights"])
            backend.notify.emit("Sigilo desactivado", True)
            return "off"
        backend._stealth = {"profile": backend.profile or "balanced",
                            "lights": (ls.get("effect", "static"), ls.get("color", "FFFFFF"),
                                       int(ls.get("brightness", 100)))}
        backend.setProfile("power-saver")
        if ls.get("available") and ls.get("via") != "none":
            backend.setLights("static", "FFFFFF", 15)
        backend.notify.emit("Sigilo activado: Silencioso y luces tenues", True)
        return "on"
    if action == "lights":
        ls = backend.lightsState
        cur = 0 if ls.get("effect") == "off" else int(ls.get("brightness", 100))
        nxt = next((lv for lv in LIGHT_LEVELS if lv < cur), LIGHT_LEVELS[0])
        effect = ls.get("effect", "static")
        if effect == "off":
            effect = "static"
        backend.setLights(effect, ls.get("color", "FFFFFF"), nxt)
        return str(nxt)
    if action.startswith("mode:"):
        backend.setProfile(action[5:])
        return action[5:]
    return "acción desconocida"


def start_server(handler, sock: Path = SOCKET) -> QLocalServer | None:
    """Socket local (solo el usuario) para instancia única y órdenes rápidas.
    handler(orden) -> respuesta."""
    RUNTIME.mkdir(parents=True, exist_ok=True)
    os.chmod(RUNTIME, 0o700)
    server = QLocalServer()
    server.setSocketOptions(QLocalServer.SocketOption.UserAccessOption)
    QLocalServer.removeServer(str(sock))
    if not server.listen(str(sock)):
        return None

    def on_conn():
        sock = server.nextPendingConnection()

        def read():
            cmd = bytes(sock.readAll()).decode(errors="ignore").strip()
            reply = handler(cmd) if cmd else ""
            sock.write((reply + "\n").encode())
            sock.flush()
            sock.disconnectFromServer()

        sock.readyRead.connect(read)

    server.newConnection.connect(on_conn)
    return server


def send_to_running(cmd: str, timeout: float = 1.5, sock: Path = SOCKET) -> str | None:
    """Envía una orden a una instancia en marcha (sin cargar Qt). None si no hay."""
    import socket

    if not sock.exists():
        return None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            s.connect(str(sock))
            s.sendall(cmd.encode())
            return s.recv(256).decode(errors="ignore").strip()
    except OSError:
        return None


def set_autostart(on: bool) -> None:
    if on:
        AUTOSTART.parent.mkdir(parents=True, exist_ok=True)
        AUTOSTART.write_text(f"""[Desktop Entry]
Type=Application
Name=Vórtice
Comment=Centro de control del portátil (bandeja)
Exec={launcher()} --bandeja
Icon=vortice
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
""")
    elif AUTOSTART.exists():
        AUTOSTART.unlink()


# ---- teclas Alienware como atajos globales de KDE ------------------------------
# F9 (luces) llega como XF86Launch9. F6 (boost, KEY_PERFORMANCE sin símbolo XKB)
# y F7 (sigilo, F20 = "silenciar micrófono") se reasignan con la regla hwdb del
# servicio a F23 y F24, que XKB y Qt traducen sin ambigüedad.
KEY_SHORTCUTS = {"lights": "Launch (9)", "stealth": "F24", "boost": "F23"}
SHORTCUTS_FILE = Path(os.path.expanduser("~/.local/share/applications/vortice-teclas.desktop"))


def install_key_shortcuts() -> bool:
    """Atajos globales vía archivo .desktop con X-KDE-Shortcuts (los lee kglobalaccel)."""
    cmd = launcher()
    names = {"lights": "Ciclar brillo de las luces", "stealth": "Modo sigilo", "boost": "Alternar modo Rendimiento"}
    body = f"""[Desktop Entry]
Type=Application
Name=Vórtice (teclas)
Comment=Teclas especiales del portátil: F6 Boost, F7 Sigilo, F9 Luces
Icon=vortice
Exec={cmd} --accion show
NoDisplay=true
StartupNotify=false
X-KDE-StartupNotify=false
Actions={";".join(KEY_SHORTCUTS)};
"""
    for action, key in KEY_SHORTCUTS.items():
        body += f"""
[Desktop Action {action}]
Name={names[action]}
Exec={cmd} --accion {action}
X-KDE-Shortcuts={key}
"""
    try:
        if SHORTCUTS_FILE.exists() and SHORTCUTS_FILE.read_text() == body:
            return False
        SHORTCUTS_FILE.parent.mkdir(parents=True, exist_ok=True)
        SHORTCUTS_FILE.write_text(body)
        return True
    except OSError:
        return False


def _qt_key_code(name: str) -> int | None:
    """Código Qt de una tecla a partir de su nombre ("F23", "Launch (9)"). Se
    calcula con Qt en lugar de una tabla a mano: un error ahí capturaba F7/F8."""
    from PySide6.QtGui import QKeySequence

    seq = QKeySequence.fromString(name, QKeySequence.SequenceFormat.PortableText)
    return seq[0].toCombined() if seq.count() == 1 else None


def apply_key_shortcuts() -> None:
    """Tras cambiar el archivo, KDE conserva el atajo activo anterior: se le
    indica también por D-Bus (kglobalaccel) la tecla nueva."""
    import subprocess

    subprocess.run(["kbuildsycoca6"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
    names = {"lights": "Ciclar brillo de las luces", "stealth": "Modo sigilo", "boost": "Alternar modo Rendimiento"}
    for action, key in KEY_SHORTCUTS.items():
        code = _qt_key_code(key)
        if code is None:
            continue
        subprocess.run(["busctl", "--user", "call", "org.kde.kglobalaccel", "/kglobalaccel",
                        "org.kde.KGlobalAccel", "setForeignShortcut", "asai", "4",
                        SHORTCUTS_FILE.name, action, "Vórtice (teclas)", names[action], "1", str(code)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
