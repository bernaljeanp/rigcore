"""Biblioteca de juegos y configuración de perfiles por juego (lado interfaz).

El agente (agent.py) aplica los perfiles; este módulo solo lista juegos y
edita ~/.config/rigcore/games.json de forma atómica.
"""

from __future__ import annotations

import glob
import json
import os
import re
import subprocess
from pathlib import Path

from . import agent
from .i18n import tr

STEAM_ROOTS = ["~/.local/share/Steam", "~/.steam/steam",
               "~/.var/app/com.valvesoftware.Steam/.local/share/Steam"]

# Herramientas de Steam que no son juegos.
_NOT_GAMES = re.compile(r"Steam Linux Runtime|Proton|Steamworks Common|SteamVR|Steam Audio", re.I)

# Juegos conocidos que no son de Steam: proceso -> (nombre, id de Flatpak para el icono).
KNOWN_PROCESSES = {
    "sober": ("Roblox (Sober)", "org.vinegarhq.Sober"),
}

AGENT_UNIT = "rigcore-agent.service"


def _vdf_values(text: str, key: str) -> list[str]:
    return re.findall(rf'"{key}"\s+"([^"]*)"', text)


def steam_root() -> Path | None:
    for r in STEAM_ROOTS:
        p = Path(os.path.expanduser(r))
        if (p / "steamapps").is_dir():
            return p.resolve()
    return None


def _art(root: Path, appid: str) -> dict:
    """Portada vertical, cabecera y fondo desde la caché de la biblioteca de Steam."""
    base = root / "appcache" / "librarycache"
    out = {}
    for key, names in (("cover", ["library_600x900.jpg", f"{appid}_library_600x900.jpg"]),
                       ("hero", ["library_hero.jpg", f"{appid}_library_hero.jpg"]),
                       ("header", ["header.jpg", f"{appid}_header.jpg"])):
        for n in names:
            hits = glob.glob(str(base / appid / "**" / n), recursive=True) or glob.glob(str(base / n))
            if hits:
                out[key] = "file://" + hits[0]
                break
    return out


def steam_games() -> list[dict]:
    root = steam_root()
    if not root:
        return []
    libs = {root}
    lf = root / "steamapps" / "libraryfolders.vdf"
    if lf.exists():
        libs |= {Path(p) for p in _vdf_values(lf.read_text(errors="ignore"), "path")}
    games = []
    for lib in libs:
        for acf in glob.glob(str(lib / "steamapps" / "appmanifest_*.acf")):
            text = Path(acf).read_text(errors="ignore")
            appid = (_vdf_values(text, "appid") or [""])[0]
            name = (_vdf_values(text, "name") or [""])[0]
            if not appid or not name or _NOT_GAMES.search(name):
                continue
            games.append({"id": f"steam:{appid}", "name": name, "kind": "steam",
                          "detail": f"Steam · AppID {appid}", **_art(root, appid)})
    return sorted(games, key=lambda g: g["name"].lower())


def _flatpak_icon(app_id: str) -> str | None:
    for base in ("/var/lib/flatpak/exports/share/icons/hicolor",
                 os.path.expanduser("~/.local/share/flatpak/exports/share/icons/hicolor")):
        for size in ("512x512", "256x256", "128x128", "scalable"):
            for ext in ("png", "svg"):
                p = f"{base}/{size}/apps/{app_id}.{ext}"
                if os.path.exists(p):
                    return "file://" + p
    return None


def process_games(cfg: dict) -> list[dict]:
    out = []
    for proc, label in cfg.get("processes", {}).items():
        known = KNOWN_PROCESSES.get(proc)
        icon = _flatpak_icon(known[1]) if known else None
        out.append({"id": f"proc:{proc}", "name": label or proc, "kind": "process",
                    "detail": tr("Proceso") + f" · {proc}", **({"icon": icon} if icon else {})})
    return out


# ------------------------------------------------------------ configuración

def _seed_known(cfg: dict) -> bool:
    """Añade una sola vez los juegos conocidos que estén instalados (p. ej. Sober)."""
    if cfg.get("seeded"):
        return False
    for proc, (label, flatpak_id) in KNOWN_PROCESSES.items():
        if _flatpak_icon(flatpak_id) or os.path.isdir(f"/var/lib/flatpak/app/{flatpak_id}"):
            cfg.setdefault("processes", {}).setdefault(proc, label)
    cfg["seeded"] = True
    return True


def load_config() -> dict:
    try:
        with open(agent.CONFIG) as f:
            cfg = {**agent.DEFAULT_CONFIG, **json.load(f)}
    except (OSError, ValueError):
        cfg = json.loads(json.dumps(agent.DEFAULT_CONFIG))
    if _seed_known(cfg):
        save_config(cfg)   # el agente lo recarga solo (vigila la fecha del archivo)
    return cfg


def save_config(cfg: dict) -> None:
    agent.write_json_atomic(agent.CONFIG, cfg)


def agent_state() -> dict:
    try:
        with open(agent.STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


# ------------------------------------------------------- servicio del agente

def _systemctl(*args: str) -> tuple[bool, str]:
    if os.path.exists("/.flatpak-info"):
        return False, "no disponible en Flatpak"
    try:
        r = subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=10)
        return r.returncode == 0, (r.stdout + r.stderr).strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)


def agent_active() -> bool:
    return _systemctl("is-active", AGENT_UNIT)[1] == "active"


def install_agent() -> tuple[bool, str]:
    """Instala y arranca el agente como servicio de usuario (sin root).
    Si un paquete de la distro ya trae la unidad, solo se activa."""
    for packaged in ("/usr/lib/systemd/user", "/usr/local/lib/systemd/user"):
        if os.path.exists(f"{packaged}/{AGENT_UNIT}"):
            _systemctl("daemon-reload")
            return _systemctl("enable", "--now", AGENT_UNIT)
    unit_dir = Path(os.path.expanduser("~/.config/systemd/user"))
    unit_dir.mkdir(parents=True, exist_ok=True)
    script = Path(agent.__file__).resolve()
    appimage = os.environ.get("APPIMAGE")
    # Desde un AppImage, la ruta de agent.py cambia en cada arranque: se lanza el
    # propio archivo con --agente (usa el Python incluido).
    exec_line = f"{appimage} --agente" if appimage else f"/usr/bin/python3 -I {script}"
    (unit_dir / AGENT_UNIT).write_text(f"""[Unit]
Description=Rigcore - perfiles por juego
After=graphical-session.target

[Service]
ExecStart={exec_line}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
""")
    _systemctl("daemon-reload")
    return _systemctl("enable", "--now", AGENT_UNIT)


def conflicting_services() -> list[str]:
    """Otros servicios que cambian el perfil al jugar y competirían con el agente."""
    found = []
    for unit in ("modo-juego-auto.service", "gamemoded.service"):
        if _systemctl("is-active", unit)[1] == "active":
            found.append(unit)
    return found


def disable_service(unit: str) -> tuple[bool, str]:
    if unit not in ("modo-juego-auto.service",):
        return False, "servicio no permitido"
    return _systemctl("disable", "--now", unit)
