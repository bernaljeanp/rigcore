#!/usr/bin/python3 -I
"""Muestra el código de escaneo y la tecla que envía el teclado interno.

Uso (necesita root para leer /dev/input):
    pkexec /usr/bin/python3 -I tools/scan_keys.py [segundos]
Pulsa las teclas especiales (F6 Boost, F7 Sigilo, F9 Luces...) mientras corre.
Solo lee el teclado interno y no guarda nada: imprime lo que ve y termina.
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


def internal_keyboard():
    for ev in sorted(glob.glob("/sys/class/input/event*")):
        try:
            with open(f"{ev}/device/name") as f:
                if f.read().strip() == "AT Translated Set 2 keyboard":
                    return "/dev/input/" + os.path.basename(ev)
        except OSError:
            pass
    return None


def main():
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 15
    dev = internal_keyboard()
    if not dev:
        sys.exit("No se encontró el teclado interno.")
    print(f"Leyendo {dev} durante {secs:.0f} s. Pulsa F6, F7 y F9 (una vez cada una)...", flush=True)
    fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
    end, scan, seen = time.time() + secs, None, []
    try:
        while time.time() < end:
            if not select.select([fd], [], [], 0.2)[0]:
                continue
            data = os.read(fd, SIZE * 64)
            for i in range(0, len(data) - SIZE + 1, SIZE):
                _, _, typ, code, value = struct.unpack(FMT, data[i:i + SIZE])
                if typ == EV_MSC and code == MSC_SCAN:
                    scan = value
                elif typ == EV_KEY and value == 1:
                    name = NAMES.get(code, f"código {code}")
                    line = f"tecla {name:12s} scancode {scan:#x}" if scan is not None else f"tecla {name}"
                    if line not in seen:
                        seen.append(line)
                        print("  " + line, flush=True)
                    scan = None
    finally:
        os.close(fd)
    print("Listo." if seen else "No se pulsó ninguna tecla.")


if __name__ == "__main__":
    main()
