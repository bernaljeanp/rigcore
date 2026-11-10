#!/usr/bin/python3 -I
"""Agente de perfiles por juego de Vórtice (servicio de usuario, sin root).

Vigila los procesos cada pocos segundos y, cuando se abre un juego configurado,
aplica su modo de rendimiento (y el boost de ventiladores si el servicio de
Vórtice está instalado). Al cerrarse el juego restaura el estado anterior.

Diseñado para no gastar nada: solo biblioteca estándar, lectura incremental de
/proc (cada PID se inspecciona una vez) y llamadas a D-Bus solo en las
transiciones.

Configuración: ~/.config/vortice/games.json   (la edita la interfaz)
Estado:        $XDG_RUNTIME_DIR/vortice/agent.json (lo lee la interfaz)
"""

import json
import os
import signal
import subprocess
import sys
import time

INTERVAL = 3.0
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                      "vortice", "games.json")
RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "vortice")
STATE = os.path.join(RUNTIME, "agent.json")

PPD = ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles")
HELPER = ("io.github.vortice.Helper", "/io/github/vortice/Helper1", "io.github.vortice.Helper1")
MODES = ("power-saver", "balanced", "performance")

DEFAULT_CONFIG = {
    "enabled": True,
    "acOnly": True,                      # solo con el cargador conectado
    "default": {"mode": "performance", "boost": 0},   # juegos sin perfil propio
    "games": {},                         # "steam:730": {"mode": ..., "boost": 0-255}
    "processes": {},                     # "sober": "Roblox (Sober)"  -> id "proc:sober"
}


def log(msg):
    print(msg, flush=True)


# ------------------------------------------------------------- utilidades --

def busctl(*args):
    try:
        r = subprocess.run(["busctl", "--system", *args], capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def get_profile():
    out = busctl("get-property", *PPD, "ActiveProfile")
    return out.split(" ", 1)[-1].strip('"') if out else None


def set_profile(name):
    return busctl("set-property", *PPD, "ActiveProfile", "s", name) is not None


def helper_fan_count():
    out = busctl("--json=short", "call", *HELPER, "GetState")
    if not out:
        return 0
    try:
        return len(json.loads(json.loads(out)["data"][0]).get("fans", []))
    except (ValueError, KeyError, IndexError, TypeError):
        return 0


def set_boost(value):
    n = helper_fan_count()
    for i in range(n):
        busctl("call", *HELPER, "SetFanBoost", "ii", str(i), str(int(value)))
    return n > 0


def on_ac():
    for name in os.listdir("/sys/class/power_supply"):
        base = f"/sys/class/power_supply/{name}"
        try:
            with open(f"{base}/type") as f:
                if f.read().strip() != "Mains":
                    continue
            with open(f"{base}/online") as f:
                if f.read().strip() == "1":
                    return True
        except OSError:
            continue
    return False


def write_json_atomic(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


# --------------------------------------------------------- configuración --

class Config:
    def __init__(self):
        self.mtime = None
        self.data = dict(DEFAULT_CONFIG)

    def reload_if_changed(self):
        try:
            m = os.stat(CONFIG).st_mtime
        except FileNotFoundError:
            if self.mtime is None:
                write_json_atomic(CONFIG, DEFAULT_CONFIG)
            return
        if m == self.mtime:
            return
        self.mtime = m
        try:
            with open(CONFIG) as f:
                self.data = {**DEFAULT_CONFIG, **json.load(f)}
            log("configuración cargada")
        except (OSError, ValueError) as e:
            log(f"configuración inválida, se mantiene la anterior: {e}")

    def settings_for(self, game_id):
        """Modo y boost para un juego, o None si no hay que tocar nada."""
        s = self.data["games"].get(game_id) or self.data["default"]
        mode = s.get("mode")
        if mode not in MODES:
            return None  # "sin cambios"
        boost = int(s.get("boost") or 0)
        return {"mode": mode, "boost": max(0, min(255, boost))}


# --------------------------------------------------------------- procesos --

class Scanner:
    """Lectura incremental de /proc: cada PID nuevo se inspecciona una sola vez."""

    def __init__(self):
        self.known = {}   # pid -> id de juego o None

    @staticmethod
    def identify(pid, processes):
        try:
            with open(f"/proc/{pid}/comm") as f:
                comm = f.read().strip()
            if comm in processes:
                return f"proc:{comm}"
            if comm != "reaper":
                return None
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            return None
        # Steam lanza cada juego (nativo o Proton) bajo: reaper SteamLaunch AppId=NNN -- ...
        if b"SteamLaunch" in args:
            for a in args:
                if a.startswith(b"AppId="):
                    appid = a[6:].decode(errors="ignore")
                    if appid.isdigit() and appid != "0":
                        return f"steam:{appid}"
        return None

    def running(self, processes):
        pids = {int(p) for p in os.listdir("/proc") if p.isdigit()}
        for gone in self.known.keys() - pids:
            del self.known[gone]
        for pid in pids - self.known.keys():
            self.known[pid] = self.identify(pid, processes)
        return sorted({g for g in self.known.values() if g})


# ------------------------------------------------------------------ bucle --

class Agent:
    def __init__(self):
        self.cfg = Config()
        self.scan = Scanner()
        self.active = None       # juego al que hemos aplicado ajustes
        self.prev_profile = None
        self.applied = None      # {"mode", "boost"} que aplicamos

    def apply(self, game, settings):
        self.prev_profile = get_profile()
        if settings["mode"] != self.prev_profile:
            set_profile(settings["mode"])
        if settings["boost"] > 0:
            set_boost(settings["boost"])
        self.active, self.applied = game, settings
        log(f"{game}: {self.prev_profile} -> {settings['mode']}"
            + (f", boost {settings['boost']}" if settings["boost"] else ""))

    def restore(self, reason):
        if not self.active:
            return
        # Si el usuario cambió el modo a mano durante la partida, se respeta.
        if self.prev_profile and get_profile() == self.applied["mode"] \
                and self.prev_profile != self.applied["mode"]:
            set_profile(self.prev_profile)
        if self.applied["boost"] > 0:
            set_boost(0)
        log(f"{self.active}: restaurado ({reason})")
        self.active = self.applied = self.prev_profile = None

    def write_state(self, running):
        write_json_atomic(STATE, {
            "pid": os.getpid(),
            "updated": time.time(),
            "running": running,
            "active": self.active,
            "applied": self.applied,
            "previous": self.prev_profile,
        })

    def tick(self):
        self.cfg.reload_if_changed()
        c = self.cfg.data
        running = self.scan.running(set(c.get("processes", {}).keys()))
        # Un juego con perfil propio tiene prioridad sobre uno sin configurar.
        game = next((g for g in running if g in c["games"]), running[0] if running else None)
        settings = self.cfg.settings_for(game) if game else None
        allowed = c["enabled"] and (on_ac() or not c["acOnly"])

        want = game if (game and settings and allowed) else None
        if want != self.active:
            if self.active:
                self.restore("juego cerrado" if not game else "condiciones cambiaron")
            if want:
                self.apply(want, settings)
            self.write_state(running)
        elif want and settings != self.applied:
            # Se cambió el perfil del juego activo desde la interfaz.
            if settings["mode"] != self.applied["mode"]:
                set_profile(settings["mode"])
            if settings["boost"] != self.applied["boost"]:
                set_boost(settings["boost"])
            self.applied = settings
            self.write_state(running)
        elif int(time.time()) % 30 < INTERVAL:
            self.write_state(running)  # latido para que la interfaz sepa que vive

    def run(self):
        def stop(*_):
            self.restore("agente detenido")
            try:
                os.remove(STATE)
            except OSError:
                pass
            sys.exit(0)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        log("agente de perfiles por juego iniciado")
        self.write_state([])
        while True:
            try:
                self.tick()
            except Exception as e:  # nunca morir por un fallo puntual
                log(f"error: {e!r}")
            time.sleep(INTERVAL)


def main():
    Agent().run()


if __name__ == "__main__":
    main()
