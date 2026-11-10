"""Control de ventiladores para varias marcas, sobre interfaces estándar del kernel.

Cada ventilador se detecta con un "tipo" según lo que exponga su driver:

  boost   Alienware/Dell G (alienware-wmi): fanN_boost 0-255, se suma a la curva
          del firmware. Nunca deja el ventilador por debajo de lo que pide el EC.
  pwm     ThinkPad (fan_control=1), Dell (dell_smm), HP Victus S, sobremesas:
          pwmN_enable 1 = manual con pwmN 0-255, 2 = automático (firmware).
  mode    ASUS (asus-wmi), HP Omen/Victus: pwmN_enable 0 = máximo, 2 = automático.
  toggle  MSI (msi-ec): cooler_boost on/off.
  acer    Acer Predator/Nitro (Linuwu-Sense): fan_speed "cpu,gpu", 0 = auto, 1-100 %.

Vórtice pide a todos lo mismo: un valor 0-255 ("cuánto refuerzo"). Cada tipo lo
traduce a lo que entiende su driver. Reglas de seguridad:
  - 0 significa SIEMPRE devolver el control al firmware (automático).
  - En modo manual (pwm), a 90 °C o más se fuerza el máximo hasta bajar de 85 °C.
  - El servicio llama a reset() al detenerse: todo vuelve a automático.

Solo biblioteca estándar. `root` permite usar un sysfs simulado en las pruebas.
"""

from __future__ import annotations

import glob
import os

HOT, COOL = 90.0, 85.0        # °C: forzar máximo / soltar en modo manual
MODE_MAX_AT = 204             # en ventiladores sin control fino: >= 80 % -> máximo


def _read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


ALLOWED_PREFIX = "/sys/"     # las pruebas lo cambian a su sysfs simulado


def _write(path, value):
    real = os.path.realpath(path)
    if not real.startswith(os.path.realpath(ALLOWED_PREFIX)):
        raise OSError(f"ruta fuera de {ALLOWED_PREFIX}: {path}")
    with open(real, "w") as f:
        f.write(str(value))


def _p(root, path):
    return os.path.join(root, path.lstrip("/"))


def _temp_for(root, hwmon, label):
    """Sensor del mismo driver con el nombre del ventilador ("CPU Fan" -> "CPU");
    si no, el paquete de la CPU (coretemp / k10temp)."""
    word = label.split()[0].lower() if label else ""
    for lbl in sorted(glob.glob(f"{hwmon}/temp*_label")):
        if (_read(lbl) or "").lower() == word:
            return lbl.replace("_label", "_input")
    for hw in sorted(glob.glob(_p(root, "/sys/class/hwmon/hwmon*"))):
        if _read(f"{hw}/name") in ("coretemp", "k10temp", "zenpower"):
            for lbl in glob.glob(f"{hw}/temp*_label"):
                if _read(lbl) in ("Package id 0", "Tctl", "Tdie"):
                    return lbl.replace("_label", "_input")
            return f"{hw}/temp1_input"
    return None


def _thinkpad_manual_allowed(root):
    v = _read(_p(root, "/sys/module/thinkpad_acpi/parameters/fan_control"))
    return v in ("Y", "1")


def detect(root: str = "/") -> list[dict]:
    """Ventiladores controlables, en orden estable."""
    fans = []
    for hw in sorted(glob.glob(_p(root, "/sys/class/hwmon/hwmon*")),
                     key=lambda p: int(p.rsplit("hwmon", 1)[1] or 0)):
        name = _read(f"{hw}/name") or ""
        if name == "asus_custom_fan_curve":
            continue  # curva por hardware: se gestiona aparte (asus_curve_paths)
        for fin in sorted(glob.glob(f"{hw}/fan*_input")):
            n = os.path.basename(fin)[3:-6]          # "fan1_input" -> "1"
            base = f"{hw}/fan{n}"
            label = _read(f"{base}_label") or ("CPU Fan" if n == "1" else "GPU Fan" if n == "2" else f"Fan {n}")
            pwm, enable = f"{hw}/pwm{n}", f"{hw}/pwm{n}_enable"
            fan = {"label": label, "driver": name, "input": fin, "max": None,
                   "temp": _temp_for(root, hw, label)}
            mx = _read(f"{base}_max")
            fan["max"] = int(mx) if mx and mx.isdigit() else None

            if os.path.exists(f"{base}_boost"):
                fan.update(kind="boost", boost=f"{base}_boost")
            elif name == "thinkpad":
                if not (os.path.exists(enable) and _thinkpad_manual_allowed(root)):
                    continue  # sin fan_control=1 el driver no deja controlar
                fan.update(kind="pwm", pwm=pwm, enable=enable)
            elif name in ("asus", "asus_nb_wmi"):
                if not os.path.exists(enable):
                    continue
                fan.update(kind="mode", enable=enable)
            elif name == "hp":
                if not os.path.exists(enable):
                    continue
                # Los Victus S permiten pwm manual (pwmN escribible); el resto, auto/máximo.
                writable = os.path.exists(pwm) and os.stat(pwm).st_mode & 0o200
                fan.update(kind="pwm", pwm=pwm, enable=enable) if writable else fan.update(kind="mode", enable=enable)
            elif os.path.exists(pwm) and os.path.exists(enable):
                fan.update(kind="pwm", pwm=pwm, enable=enable)   # dell_smm, sobremesas...
            else:
                continue
            fans.append(fan)

    # Un mismo ventilador puede aparecer en dos drivers (p. ej. alienware_wmi y
    # dell_smm en un Alienware). Controlarlo por dos vías haría que se pelearan:
    # se queda solo el preferido por ventilador.
    preference = {"boost": 0, "mode": 1, "pwm": 2}
    best = {}
    for f in fans:
        cur = best.get(f["label"])
        if cur is None or preference[f["kind"]] < preference[cur["kind"]]:
            best[f["label"]] = f
    fans = [f for f in fans if best.get(f["label"]) is f]

    # Acer Predator / Nitro con Linuwu-Sense: un archivo para los dos ventiladores.
    for sense in ("predator_sense", "nitro_sense"):
        fs = _p(root, f"/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/{sense}/fan_speed")
        if os.path.exists(fs) and not fans:
            for i, lbl in enumerate(("CPU Fan", "GPU Fan")):
                fans.append({"label": lbl, "driver": "linuwu_sense", "input": None, "max": None,
                             "kind": "acer", "file": fs, "slot": i, "temp": _temp_for(root, "", "")})
            break

    # MSI (msi-ec): un único interruptor de refuerzo para todos los ventiladores.
    # Se asocia a los dos ventiladores para que el panel lo muestre en ambas tarjetas.
    cb = _p(root, "/sys/devices/platform/msi-ec/cooler_boost")
    if os.path.exists(cb) and not fans:
        for lbl in ("CPU Fan", "GPU Fan"):
            fans.append({"label": lbl, "driver": "msi-ec", "input": None, "max": None,
                         "kind": "toggle", "toggle": cb, "temp": _temp_for(root, "", "")})
    return fans


def levels(kind: str) -> list[str]:
    """Qué puede ofrecer la interfaz: un deslizador o solo auto/máximo."""
    return ["auto", "max"] if kind in ("mode", "toggle") else ["range"]


class Controller:
    """Aplica el valor efectivo (0-255) de un ventilador según su tipo."""

    def __init__(self):
        self.hot = {}        # índice -> bool (forzado al máximo por temperatura)

    def apply(self, index: int, fan: dict, value: int, temp: float | None) -> str:
        """Devuelve una descripción breve de lo aplicado (para pruebas y registro)."""
        value = max(0, min(255, int(value)))
        kind = fan["kind"]

        if kind == "boost":
            _write(fan["boost"], value)
            return f"boost {value}"

        if kind == "pwm":
            # Seguridad: en manual, con mucha temperatura, al máximo.
            if temp is not None:
                if temp >= HOT:
                    self.hot[index] = True
                elif temp < COOL:
                    self.hot[index] = False
            if self.hot.get(index) and value > 0:
                value = 255
            if value == 0:
                _write(fan["enable"], 2)                 # firmware
                return "auto"
            _write(fan["enable"], 1)
            _write(fan["pwm"], value)
            return f"pwm {value}"

        if kind == "mode":
            if value >= MODE_MAX_AT:
                _write(fan["enable"], 0)                 # máximo
                return "max"
            _write(fan["enable"], 2)
            return "auto"

        if kind == "toggle":
            on = value >= MODE_MAX_AT
            _write(fan["toggle"], "on" if on else "off")
            return "max" if on else "auto"

        if kind == "acer":
            # Mismo archivo para CPU y GPU: se reescribe el par conservando el otro.
            pct = 0 if value == 0 else max(1, round(value / 2.55))
            cur = (_read(fan["file"]) or "0,0").split(",")
            cur = (cur + ["0", "0"])[:2]
            cur[fan["slot"]] = str(pct)
            _write(fan["file"], ",".join(cur))
            return "auto" if pct == 0 else f"{pct} %"
        return "?"

    @staticmethod
    def reset(fan: dict) -> None:
        """Devolver el ventilador al firmware (al detener el servicio)."""
        try:
            if fan["kind"] == "boost":
                _write(fan["boost"], 0)
            elif fan["kind"] in ("pwm", "mode"):
                _write(fan["enable"], 2)
            elif fan["kind"] == "toggle":
                _write(fan["toggle"], "off")
            elif fan["kind"] == "acer":
                _write(fan["file"], "0,0")
        except OSError:
            pass


def read_value(fan: dict) -> int | None:
    """Valor actual leído del driver, si lo informa de forma fiable."""
    if fan["kind"] == "pwm":
        if _read(fan["enable"]) == "2":
            return 0
        v = _read(fan["pwm"])
        return int(v) if v and v.isdigit() else None
    if fan["kind"] == "mode":
        return 255 if _read(fan["enable"]) == "0" else 0
    if fan["kind"] == "toggle":
        return 255 if _read(fan["toggle"]) == "on" else 0
    if fan["kind"] == "acer":
        parts = (_read(fan["file"]) or "0,0").split(",")
        try:
            return round(int(parts[fan["slot"]]) * 2.55)
        except (ValueError, IndexError):
            return None
    return None  # alienware-wmi devuelve 0 aunque el boost esté activo


# ---- ASUS: curva de ventilador en el propio firmware ---------------------------

def asus_curve_paths(root: str = "/") -> dict | None:
    """{pwm_index: [(temp_path, pwm_path) x8], enable paths} si el equipo la tiene."""
    for hw in glob.glob(_p(root, "/sys/class/hwmon/hwmon*")):
        if _read(f"{hw}/name") != "asus_custom_fan_curve":
            continue
        out = {}
        for n in (1, 2, 3):
            pts = [(f"{hw}/pwm{n}_auto_point{k}_temp", f"{hw}/pwm{n}_auto_point{k}_pwm") for k in range(1, 9)]
            if all(os.path.exists(t) and os.path.exists(p) for t, p in pts):
                out[n] = {"points": pts, "enable": f"{hw}/pwm{n}_enable"}
        return out or None
    return None


def resample(points: list, n: int = 8) -> list[tuple[int, int]]:
    """Convierte una curva de 2-8 puntos (temp °C, %) en n puntos (temp, pwm 0-255)
    crecientes, como exige el firmware de ASUS."""
    t0, t1 = points[0][0], points[-1][0]

    def at(t):
        if t <= points[0][0]:
            return points[0][1]
        for (a, pa), (b, pb) in zip(points, points[1:]):
            if t <= b:
                return pa + (pb - pa) * (t - a) / (b - a)
        return points[-1][1]

    out, last = [], -1
    for k in range(n):
        t = round(t0 + (t1 - t0) * k / (n - 1))
        t = max(t, out[-1][0] + 1) if out else t
        pwm = max(last, round(at(t) * 2.55))      # el firmware exige valores no decrecientes
        out.append((t, pwm))
        last = pwm
    return out


def apply_asus_curve(paths: dict, curves_by_index: dict) -> None:
    """Escribe la curva en el firmware (pwmN_enable=1). curves_by_index: {1: puntos, ...}."""
    for n, pts in curves_by_index.items():
        if n not in paths:
            continue
        for (tp, pp), (t, pwm) in zip(paths[n]["points"], resample(pts)):
            _write(tp, t)
            _write(pp, pwm)
        _write(paths[n]["enable"], 1)


def disable_asus_curve(paths: dict) -> None:
    for n in paths:
        try:
            _write(paths[n]["enable"], 2)    # modo de fábrica (conserva la curva)
        except OSError:
            pass
