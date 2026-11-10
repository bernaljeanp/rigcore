"""Lectura de gráficas: NVIDIA (NVML), AMD (amdgpu) e Intel (i915/xe).

Reglas comunes:
- Se elige la gráfica más relevante: dedicada antes que integrada.
- Una gráfica dedicada dormida (runtime PM "suspended") NO se consulta:
  leer sus sensores la despertaría y gastaría batería en modo híbrido.
- `root` permite apuntar a un sysfs simulado para pruebas.
"""

from __future__ import annotations

import ctypes
import glob
import os
import time


def _read(path: str) -> str | None:
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def _int(path: str) -> int | None:
    v = _read(path)
    try:
        return int(v) if v is not None else None
    except ValueError:
        return None


def pci_name(vendor: str, device: str, root: str = "/") -> str | None:
    """Nombre comercial desde la base pci.ids (hwdata), p. ej. 'Navi 33 [Radeon RX 7600M]'."""
    vendor, device = vendor.lower().removeprefix("0x"), device.lower().removeprefix("0x")
    for db in ("usr/share/hwdata/pci.ids", "usr/share/misc/pci.ids"):
        path = os.path.join(root, db)
        if not os.path.exists(path):
            continue
        in_vendor = False
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                if not line.startswith("\t"):
                    in_vendor = line.startswith(vendor + " ")
                elif in_vendor and not line.startswith("\t\t") and line[1:5] == device:
                    return line[5:].strip()
    return None


def _short(name: str) -> str:
    """'Navi 33 [Radeon RX 7600M XT]' -> 'Radeon RX 7600M XT'.
    Si el nombre comercial es genérico, añade el nombre en clave:
    'Arrow Lake-S [Intel Graphics]' -> 'Intel Graphics (Arrow Lake)'."""
    if "[" in name and "]" in name:
        code, inner = name[: name.index("[")].strip(), name[name.index("[") + 1 : name.rindex("]")]
        inner = inner.split("/")[0].strip()
        if inner in ("Intel Graphics", "AMD Radeon Graphics", "Radeon Graphics") and code:
            return f"{inner} ({code.split('-')[0].strip()})"
        return inner
    return name.split("/")[0].strip()


class Gpu:
    kind = "none"
    name = ""
    discrete = False

    def __init__(self, device_dir: str = "") -> None:
        self.dev = device_dir

    def asleep(self) -> bool:
        return self.discrete and _read(f"{self.dev}/power/runtime_status") == "suspended"

    def read(self) -> dict:
        return {}

    def sample(self) -> dict:
        if self.asleep():
            return {"asleep": True}
        return self.read()


# ---------------------------------------------------------------- NVIDIA ---

class _NvUtil(ctypes.Structure):
    _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]


class NvidiaGpu(Gpu):
    kind = "nvidia"
    discrete = True

    def __init__(self, device_dir: str) -> None:
        super().__init__(device_dir)
        self.ok = False
        self._init = False
        self.name = "NVIDIA"
        try:
            self.lib = ctypes.CDLL("libnvidia-ml.so.1")
        except OSError:
            return
        self.ok = True
        if not self.asleep():
            self._open()

    def _open(self) -> bool:
        if self._init:
            return True
        if self.lib.nvmlInit_v2() != 0:
            return False
        self.handle = ctypes.c_void_p()
        if self.lib.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(self.handle)) != 0:
            return False
        buf = ctypes.create_string_buffer(96)
        self.lib.nvmlDeviceGetName(self.handle, buf, 96)
        self.name = buf.value.decode(errors="replace").replace("NVIDIA GeForce ", "")
        self._init = True
        return True

    def read(self) -> dict:
        if not self.ok or not self._open():
            return {}
        h, out, lib = self.handle, {}, self.lib
        t, p, lim, c = ctypes.c_uint(), ctypes.c_uint(), ctypes.c_uint(), ctypes.c_uint()
        if lib.nvmlDeviceGetTemperature(h, 0, ctypes.byref(t)) == 0:
            out["temp"] = t.value
        if lib.nvmlDeviceGetPowerUsage(h, ctypes.byref(p)) == 0:
            out["power"] = p.value / 1000
        if lib.nvmlDeviceGetEnforcedPowerLimit(h, ctypes.byref(lim)) == 0:
            out["power_limit"] = lim.value / 1000
        u = _NvUtil()
        if lib.nvmlDeviceGetUtilizationRates(h, ctypes.byref(u)) == 0:
            out["util"] = u.gpu
        if lib.nvmlDeviceGetClockInfo(h, 0, ctypes.byref(c)) == 0:
            out["clock"] = c.value
        return out


# ------------------------------------------------------------------- AMD ---

class AmdGpu(Gpu):
    kind = "amd"

    def __init__(self, device_dir: str, root: str = "/") -> None:
        super().__init__(device_dir)
        hw = [h for h in glob.glob(f"{device_dir}/hwmon/hwmon*") if _read(f"{h}/name") == "amdgpu"]
        self.hwmon = hw[0] if hw else None
        # Integrada (APU) si apenas tiene VRAM propia (reserva de la RAM < 1 GiB).
        vram = _int(f"{device_dir}/mem_info_vram_total") or 0
        self.discrete = vram >= 1 << 30
        self.name = _read(f"{device_dir}/product_name") or _short(
            pci_name(_read(f"{device_dir}/vendor") or "", _read(f"{device_dir}/device") or "", root)
            or "AMD Radeon")

    def _temp(self) -> float | None:
        if not self.hwmon:
            return None
        # Preferimos "edge" (la que muestran todas las herramientas); si no, la primera.
        for lbl in sorted(glob.glob(f"{self.hwmon}/temp*_label")):
            if _read(lbl) == "edge":
                v = _int(lbl.replace("_label", "_input"))
                return v / 1000 if v is not None else None
        v = _int(f"{self.hwmon}/temp1_input")
        return v / 1000 if v is not None else None

    def read(self) -> dict:
        out: dict = {}
        if (t := self._temp()) is not None:
            out["temp"] = t
        if (u := _int(f"{self.dev}/gpu_busy_percent")) is not None:
            out["util"] = u
        if self.hwmon:
            # power1_average (kernels antiguos) o power1_input (nuevos), en µW.
            p = _int(f"{self.hwmon}/power1_average")
            if p is None:
                p = _int(f"{self.hwmon}/power1_input")
            if p is not None:
                out["power"] = p / 1e6
            cap = _int(f"{self.hwmon}/power1_cap")
            if cap:
                out["power_limit"] = cap / 1e6
            f = _int(f"{self.hwmon}/freq1_input")  # sclk en Hz
            if f is not None:
                out["clock"] = f / 1e6
        return out


# ----------------------------------------------------------------- Intel ---

class IntelGpu(Gpu):
    kind = "intel"

    def __init__(self, device_dir: str, card_dir: str, root: str = "/") -> None:
        super().__init__(device_dir)
        self.card = card_dir
        drv = os.path.basename(os.path.realpath(f"{device_dir}/driver"))
        hw = [h for h in glob.glob(f"{device_dir}/hwmon/hwmon*") if _read(f"{h}/name") in ("i915", "xe")]
        self.hwmon = hw[0] if hw else None
        # Arc dedicada: tiene sensor de potencia propio; la integrada no.
        self.discrete = bool(self.hwmon and glob.glob(f"{self.hwmon}/power1_*"))
        self.name = _short(pci_name(_read(f"{device_dir}/vendor") or "", _read(f"{device_dir}/device") or "", root)
                           or "Intel Graphics")
        self.xe = drv == "xe"
        self._energy: tuple[float, int] | None = None

    def read(self) -> dict:
        out: dict = {}
        f = _int(f"{self.card}/gt_cur_freq_mhz")  # i915
        if f is None:
            f = _int(f"{self.dev}/tile0/gt0/freq0/cur_freq")  # xe
        if f is not None:
            out["clock"] = f
        if self.hwmon:
            for t in sorted(glob.glob(f"{self.hwmon}/temp*_input")):
                if (v := _int(t)) is not None:
                    out["temp"] = v / 1000
                    break
            # Potencia a partir del contador de energía (µJ).
            e = _int(f"{self.hwmon}/energy1_input")
            now = time.monotonic()
            if e is not None:
                if self._energy and now > self._energy[0]:
                    out["power"] = (e - self._energy[1]) / 1e6 / (now - self._energy[0])
                self._energy = (now, e)
        return out


# --------------------------------------------------------------- elección --

def detect(root: str = "/") -> list[Gpu]:
    """Todas las gráficas, ordenadas de más a menos relevante."""
    gpus: list[Gpu] = []
    sysfs = os.path.join(root, "sys/class/drm")
    for card in sorted(glob.glob(f"{sysfs}/card[0-9]*")):
        if "-" in os.path.basename(card):
            continue  # conectores (card1-DP-1...)
        dev = f"{card}/device"
        vendor = (_read(f"{dev}/vendor") or "").lower()
        if vendor == "0x10de":
            g = NvidiaGpu(dev)
            if g.ok:
                gpus.append(g)
        elif vendor == "0x1002":
            gpus.append(AmdGpu(dev, root))
        elif vendor == "0x8086":
            gpus.append(IntelGpu(dev, card, root))
    order = {"nvidia": 0, "amd": 1, "intel": 2}
    gpus.sort(key=lambda g: (not g.discrete, order.get(g.kind, 9)))
    return gpus
