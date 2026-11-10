#!/usr/bin/python3 -I
"""Muestra el código de escaneo y la tecla que envía el teclado interno.

Uso (necesita root para leer /dev/input):
    pkexec /usr/bin/python3 -I tools/scan_keys.py [segundos]
Pulsa las teclas especiales (F6 Boost, F7 Sigilo, F9 Luces...) mientras corre.
Solo lee los teclados integrados del portátil y no guarda nada: imprime lo que ve y termina.
"""

import glob
import os
import select
import struct
import sys
import time

EV_KEY, EV_MSC, MSC_SCAN = 0x01, 0x04, 0x04
FMT = "llHHi"
SIZE = struct.calcsize(FMT)
NAMES = {64: "F6", 65: "F7", 67: "F9", 187: "F17", 188: "F18", 189: "F19", 190: "F20",
         148: "PROG1", 149: "PROG2", 202: "PROG3", 203: "PROG4", 248: "MICMUTE",
         0x1d9: "PERFORMANCE"}


# Dispositivos integrados del portátil que pueden enviar teclas especiales.
INTERNAL = ("AT Translated Set 2 keyboard", "Dell WMI hotkeys", "Alienware WMI hotkeys",
            "Dell Privacy Driver", "Intel HID events", "Intel HID 5 button array")


def internal_devices():
    out = {}
    for ev in sorted(glob.glob("/sys/class/input/event*")):
        try:
            with open(f"{ev}/device/name") as f:
                name = f.read().strip()
        except OSError:
            continue
        if name in INTERNAL or "WMI" in name:
            out["/dev/input/" + os.path.basename(ev)] = name
    return out


def show_map(scancodes):
    """Pregunta al kernel (EVIOCGKEYCODE) qué tecla tiene asignada cada scancode."""
    import fcntl
    EVIOCGKEYCODE = (2 << 30) | (8 << 16) | (ord("E") << 8) | 0x04
    names = {v: k for k, v in {"F23": 193, "F24": 194, "PROG3": 202, "PROG4": 203, "F20": 190,
                               "F18": 188, "PERFORMANCE": 0x2bd}.items()}
    for path, name in internal_devices().items():
        if name != "AT Translated Set 2 keyboard":
            continue
        fd = os.open(path, os.O_RDONLY)
        try:
            for sc in scancodes:
                buf = struct.pack("II", sc, 0)
                code = struct.unpack("II", fcntl.ioctl(fd, EVIOCGKEYCODE, buf))[1]
                print(f"  scancode {sc:#x} -> {names.get(code, code)}")
        finally:
            os.close(fd)


def main():
    if "--mapa" in sys.argv:
        show_map([0x68, 0x69, 0x6b])
        return
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 15
    devs = internal_devices()
    if not devs:
        sys.exit("No se encontraron dispositivos de teclado integrados.")
    print(f"Escuchando durante {secs:.0f} s: " + ", ".join(sorted(set(devs.values()))), flush=True)
    print("Pulsa F6, F7 y F9 (una vez cada una)...", flush=True)
    fds = {}
    for path, name in devs.items():
        try:
            fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = name
        except OSError:
            pass
    end, scans, seen = time.time() + secs, {}, []
    try:
        while time.time() < end:
            ready = select.select(list(fds), [], [], 0.2)[0]
            for fd in ready:
                data = os.read(fd, SIZE * 64)
                for i in range(0, len(data) - SIZE + 1, SIZE):
                    _, _, typ, code, value = struct.unpack(FMT, data[i:i + SIZE])
                    if typ == EV_MSC and code == MSC_SCAN:
                        scans[fd] = value
                    elif typ == EV_KEY and value == 1:
                        name = NAMES.get(code, f"código {code}")
                        sc = scans.pop(fd, None)
                        line = f"tecla {name:12s} scancode {sc:#x}" if sc is not None else f"tecla {name:12s}"
                        line += f"   [{fds[fd]}]"
                        if line not in seen:
                            seen.append(line)
                            print("  " + line, flush=True)
    finally:
        for fd in fds:
            os.close(fd)
    print("Listo." if seen else "No se pulsó ninguna tecla.")


if __name__ == "__main__":
    main()
