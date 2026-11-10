"""Luces Alienware: controlador AW-ELC por USB HID (hidraw).

Protocolo documentado por alienfx-tools de T-Troll (MIT) y ya probado en este
equipo por Zenit: reportes de salida de 34 bytes (byte 0 = id de reporte 0) y
consulta de "ocupado" con HIDIOCGINPUT (byte 2 == 34).

Solo biblioteca estándar: lo usan tanto la interfaz como el servicio root.
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
