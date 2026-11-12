"""Luces del teclado para varias marcas.

Tipos de controlador (ver detect()):
  awelc       Alienware/Dell G: AW-ELC por USB HID (hidraw). Protocolo documentado
              por alienfx-tools (MIT): reportes de 34 bytes, "ocupado" con HIDIOCGINPUT.
  asus        ASUS TUF/ROG (asus-wmi): asus::kbd_backlight/kbd_rgb_mode
              "cmd modo R G B velocidad" (cmd 0 = aplicar sin guardar en la BIOS).
  legion4     Lenovo Legion 5/Pro, IdeaPad Gaming, LOQ (2020-2024): teclado de 4 zonas
              por HID (048d:c9x5). Protocolo de L5P-Keyboard-RGB (GPL-3.0): feature
              report de 33 bytes "CC 16 efecto velocidad brillo R G B x4".
  acer4       Acer Predator/Nitro (Linuwu-Sense): four_zoned_kb/per_zone_mode y
              four_zone_mode "modo,velocidad,brillo,dirección,R,G,B".
  multicolor  LED multicolor estándar (*::kbd_backlight con multi_intensity).
  brightness  Cualquier *::kbd_backlight: solo brillo.

Solo biblioteca estándar: lo usan tanto la interfaz como el servicio root.
`root` permite probar con un sysfs simulado.
"""

from __future__ import annotations

import fcntl
import glob
import os
import time

VENDOR = "0000187C"          # Alienware
ZONES = bytes(range(26))      # todas las zonas del protocolo; las inexistentes se ignoran
EFFECTS = ("static", "breathe", "aurora", "off")

# Paleta del efecto aurora (la misma que usaba Zenit).
AURORA = [(0x19, 0xFF, 0x7A), (0x00, 0xE0, 0xD0), (0x1E, 0x7B, 0xFF),
          (0x7A, 0x3C, 0xFF), (0xD0, 0x2B, 0xFF), (0x1E, 0x7B, 0xFF)]

_HIDIOCGINPUT_34 = (3 << 30) | (34 << 16) | (ord("H") << 8) | 0x0A
_MORPH_MS = 0x07CF           # ~2 s por transición


def output_report_size(descriptor: bytes) -> int:
    """Tamaño en bytes del reporte de salida más grande de un descriptor HID."""
    i, size, count, best = 0, 0, 0, 0
    while i < len(descriptor):
        b = descriptor[i]
        if b == 0xFE:  # elemento largo
            i += 3 + (descriptor[i + 1] if i + 1 < len(descriptor) else 0)
            continue
        n = (0, 1, 2, 4)[b & 3]
        value = int.from_bytes(descriptor[i + 1:i + 1 + n], "little")
        if b & 0xFC == 0x74:
            size = value
        elif b & 0xFC == 0x94:
            count = value
        elif b & 0xFC == 0x90:
            best = max(best, size * count // 8)
        i += 1 + n
    return best


def find_controller(root: str = "/") -> dict | None:
    """Devuelve {"path", "name", "sysfs"} del controlador AW-ELC, o None."""
    for d in sorted(glob.glob(os.path.join(root, "sys/class/hidraw/hidraw*"))):
        try:
            with open(f"{d}/device/uevent") as f:
                uevent = f.read()
            if VENDOR not in uevent.upper():
                continue
            with open(f"{d}/device/report_descriptor", "rb") as f:
                if output_report_size(f.read()) != 33:
                    continue
        except OSError:
            continue
        name = next((l.split("=", 1)[1] for l in uevent.splitlines() if l.startswith("HID_NAME=")), "AW-ELC")
        return {"path": f"/dev/{os.path.basename(d)}", "name": name.strip(), "sysfs": d}
    return None


def identity(ctrl: dict | None):
    """Identifica la instancia del dispositivo (cambia si el USB se reconecta)."""
    if not ctrl:
        return None
    try:
        st = os.stat(ctrl["sysfs"])
        return ctrl["path"], st.st_dev, st.st_ino
    except OSError:
        return ctrl["path"], None, None


def writable(ctrl: dict | None) -> bool:
    return bool(ctrl) and os.access(ctrl["path"], os.R_OK | os.W_OK)


def validate(effect: str, color: str, brightness: int) -> None:
    if effect not in EFFECTS:
        raise ValueError(f"efecto no válido: {effect}")
    if len(color) != 6 or any(c not in "0123456789abcdefABCDEF" for c in color):
        raise ValueError("el color debe ser RRGGBB")
    if not 0 <= int(brightness) <= 100:
        raise ValueError("el brillo debe estar entre 0 y 100")


def reports(effect: str, color: str, brightness: int) -> list[bytes]:
    """Secuencia de reportes para un ajuste (separada para poder probarla)."""
    validate(effect, color, brightness)
    rgb = int(color, 16)
    r, g, b = rgb >> 16, (rgb >> 8) & 0xFF, rgb & 0xFF
    n = len(ZONES)
    seq = [(0x03, 0x21, 0x00, 0x04, 0xFF, 0xFF),     # reinicio
           (0x03, 0x21, 0x00, 0x01, 0xFF, 0xFF)]     # inicio de programación

    def morph(colors):
        seq.append((0x03, 0x23, 0x01, 0x00, n, *ZONES))
        for i in range(0, len(colors), 3):
            acts = []
            for cr, cg, cb in colors[i:i + 3]:
                acts += (2, _MORPH_MS >> 8, _MORPH_MS & 0xFF, 0, 0x40, cr, cg, cb)
            seq.append((0x03, 0x24, *acts))

    if effect == "aurora":
        morph(AURORA)
    elif effect == "breathe":
        morph([(r, g, b), (0, 0, 0)])
    else:
        seq.append((0x03, 0x27, r, g, b, 0x00, n, *ZONES))
    seq.append((0x03, 0x21, 0x00, 0x03, 0xFF, 0xFF))  # aplicar
    level = 0 if effect == "off" else int(brightness)
    seq.append((0x03, 0x26, 100 - level, 0x00, n, *ZONES))  # atenuación
    return [bytes([0]) + bytes(o).ljust(33, b"\0") for o in seq]


def apply(effect: str, color: str, brightness: int, ctrl: dict | None = None) -> dict:
    """Envía el ajuste al controlador. Lanza RuntimeError si no hay controlador."""
    ctrl = ctrl or find_controller()
    if not ctrl:
        raise RuntimeError("No se encontró el controlador de luces Alienware (AW-ELC).")
    seq = reports(effect, color, brightness)
    fd = os.open(ctrl["path"], os.O_RDWR)
    try:
        def wait_ready() -> bool:
            buf = bytearray(34)
            for _ in range(50):
                try:
                    fcntl.ioctl(fd, _HIDIOCGINPUT_34, buf)
                except OSError:
                    return False  # este dispositivo no informa de su estado
                if buf[2] != 34:
                    return True
                time.sleep(0.02)
            raise RuntimeError("El controlador de luces sigue ocupado.")

        wait_ready()
        for i, rep in enumerate(seq):
            if os.write(fd, rep) != len(rep):
                raise OSError("Reporte de luces incompleto.")
            # Tras "aplicar" y tras la atenuación, el controlador necesita procesar.
            if i >= len(seq) - 2:
                wait_ready()
    finally:
        os.close(fd)
    return {"effect": effect, "color": color.upper(), "brightness": int(brightness), "time": time.time()}



# ---- otras marcas ----------------------------------------------------------------

EFFECTS_BY_KIND = {
    "awelc": ["static", "breathe", "aurora", "off"],
    "legion4": ["static", "breathe", "aurora", "off"],   # aurora = ciclo suave del firmware
    "asus": ["static", "breathe", "aurora", "off"],       # aurora = ciclo de color del firmware
    "acer4": ["static", "breathe", "aurora", "off"],      # aurora = onda del firmware
    "multicolor": ["static", "off"],
    "brightness": ["static", "off"],
}
ASUS_MODES = {"static": 0, "breathe": 1, "aurora": 2}
ACER_BASE = "sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"


def _r(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def _w(path, value):
    with open(path, "w") as f:
        f.write(str(value))


def _kbd_leds(root):
    return sorted(glob.glob(os.path.join(root, "sys/class/leds/*kbd_backlight*")))


LEGION_VENDOR = "0000048D"
LEGION_PRODUCTS = {"0000C955", "0000C963", "0000C965", "0000C973", "0000C975", "0000C983",
                   "0000C984", "0000C985", "0000C993", "0000C994", "0000C995"}
_LEGION_USAGE_PAGE = b"\x06\x89\xff"           # Usage Page (Vendor 0xFF89)


def find_legion(root: str = "/") -> dict | None:
    """Interfaz HID del teclado de 4 zonas de Lenovo (la que declara la usage page 0xFF89)."""
    for d in sorted(glob.glob(os.path.join(root, "sys/class/hidraw/hidraw*"))):
        try:
            with open(f"{d}/device/uevent") as f:
                uevent = f.read().upper()
            hid_id = next((l.split("=", 1)[1] for l in uevent.splitlines() if l.startswith("HID_ID=")), "")
            parts = hid_id.split(":")
            if len(parts) != 3 or parts[1] != LEGION_VENDOR or parts[2] not in LEGION_PRODUCTS:
                continue
            with open(f"{d}/device/report_descriptor", "rb") as f:
                if _LEGION_USAGE_PAGE not in f.read():
                    continue
        except OSError:
            continue
        return {"path": f"/dev/{os.path.basename(d)}", "name": "Lenovo 4 zonas", "sysfs": d}
    return None


def legion_payload(effect: str, color: str, brightness: int) -> bytes:
    """Feature report de 33 bytes del teclado de 4 zonas de Lenovo."""
    validate(effect, color, brightness)
    rgb = bytes.fromhex(color)
    p = bytearray(33)
    p[0], p[1] = 0xCC, 0x16
    p[3] = 2                                            # velocidad 1-4
    p[4] = 1 if brightness <= 50 else 2                 # brillo 1-2
    if effect == "aurora":
        p[2] = 0x06                                     # ciclo suave del firmware
    else:
        p[2] = 0x03 if effect == "breathe" else 0x01
        p[5:17] = (b"\x00\x00\x00" if effect == "off" or brightness == 0 else rgb) * 4
    return bytes(p)


def _hid_set_feature(path: str, data: bytes) -> None:
    hidiocsfeature = (3 << 30) | (len(data) << 16) | (ord("H") << 8) | 0x06
    fd = os.open(path, os.O_RDWR)
    try:
        fcntl.ioctl(fd, hidiocsfeature, bytearray(data))
    finally:
        os.close(fd)


def detect(root: str = "/") -> dict | None:
    """Controlador de luces del teclado más capaz que haya, o None."""
    aw = find_controller(root)
    if aw:
        return {**aw, "kind": "awelc", "effects": EFFECTS_BY_KIND["awelc"], "color": True}
    lg = find_legion(root)
    if lg:
        return {**lg, "kind": "legion4", "effects": EFFECTS_BY_KIND["legion4"], "color": True}
    acer = os.path.join(root, ACER_BASE)
    if os.path.exists(f"{acer}/per_zone_mode"):
        return {"kind": "acer4", "name": "Acer 4 zonas", "path": acer, "sysfs": acer,
                "effects": EFFECTS_BY_KIND["acer4"], "color": True}
    for led in _kbd_leds(root):
        name = os.path.basename(led)
        mx = int(_r(f"{led}/max_brightness") or 0) or 1
        base = {"name": name, "path": led, "sysfs": led, "max": mx}
        if os.path.exists(f"{led}/kbd_rgb_mode"):
            return {**base, "kind": "asus", "effects": EFFECTS_BY_KIND["asus"], "color": True}
        if os.path.exists(f"{led}/multi_intensity"):
            return {**base, "kind": "multicolor", "effects": EFFECTS_BY_KIND["multicolor"], "color": True}
    for led in _kbd_leds(root):
        mx = int(_r(f"{led}/max_brightness") or 0) or 1
        return {"kind": "brightness", "name": os.path.basename(led), "path": led, "sysfs": led,
                "max": mx, "effects": EFFECTS_BY_KIND["brightness"], "color": False}
    return None


def _files_for(ctrl):
    k = ctrl["kind"]
    if k in ("awelc", "legion4"):
        return [ctrl["path"]]
    if k == "acer4":
        return [f"{ctrl['path']}/per_zone_mode", f"{ctrl['path']}/four_zone_mode"]
    if k == "asus":
        return [f"{ctrl['path']}/kbd_rgb_mode", f"{ctrl['path']}/brightness"]
    if k == "multicolor":
        return [f"{ctrl['path']}/multi_intensity", f"{ctrl['path']}/brightness"]
    return [f"{ctrl['path']}/brightness"]


def can_write(ctrl: dict | None) -> bool:
    """¿Puede este proceso aplicar luces sin el servicio root?"""
    return bool(ctrl) and all(os.access(p, os.W_OK) for p in _files_for(ctrl) if os.path.exists(p))


def apply_any(effect: str, color: str, brightness: int, ctrl: dict) -> dict:
    """Aplica un ajuste al controlador detectado, sea de la marca que sea."""
    validate(effect, color, brightness)
    if effect not in ctrl["effects"]:
        effect = "static"   # efecto no soportado por este teclado: color fijo
    kind = ctrl["kind"]
    if kind == "awelc":
        return apply(effect, color, brightness, ctrl)
    if kind == "legion4":
        _hid_set_feature(ctrl["path"], legion_payload(effect, color, brightness))
        return {"effect": effect, "color": color.upper(), "brightness": int(brightness), "time": time.time()}

    rgb = int(color, 16)
    r, g, b = rgb >> 16, (rgb >> 8) & 0xFF, rgb & 0xFF
    level = 0 if effect == "off" else int(brightness)

    if kind == "acer4":
        if effect in ("static", "off"):
            _w(f"{ctrl['path']}/per_zone_mode", ",".join([color.lower()] * 4) + f",{level}")
        elif effect == "breathe":
            _w(f"{ctrl['path']}/four_zone_mode", f"1,4,{level},1,{r},{g},{b}")
        else:  # aurora -> onda
            _w(f"{ctrl['path']}/four_zone_mode", f"3,4,{level},2,0,0,0")
    elif kind == "asus":
        if effect != "off":
            # cmd 0: aplicar sin guardar en la BIOS (el servicio lo reaplica al arrancar).
            _w(f"{ctrl['path']}/kbd_rgb_mode", f"0 {ASUS_MODES[effect]} {r} {g} {b} 1")
        _w(f"{ctrl['path']}/brightness", round(level / 100 * ctrl["max"]))
    elif kind == "multicolor":
        order = (_r(f"{ctrl['path']}/multi_index") or "red green blue").split()
        val = {"red": r, "green": g, "blue": b}
        _w(f"{ctrl['path']}/multi_intensity", " ".join(str(val.get(c, 0)) for c in order))
        _w(f"{ctrl['path']}/brightness", round(level / 100 * ctrl["max"]))
    else:  # brightness
        _w(f"{ctrl['path']}/brightness", round(level / 100 * ctrl["max"]))
    return {"effect": effect, "color": color.upper(), "brightness": int(brightness), "time": time.time()}
