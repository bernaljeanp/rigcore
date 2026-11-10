"""Lectura de hardware a través de interfaces estándar del kernel.

La idea central de Vórtice: no escribir un driver por marca, sino apoyarse en
las interfaces genéricas que el kernel ya expone (hwmon, platform-profile,
firmware-attributes, power_supply) y en servicios estándar (power-profiles por
D-Bus, NVML). Así un mismo código sirve para Alienware, HP, Lenovo, ASUS...
"""

from __future__ import annotations

import glob
import os
import subprocess
import time
from dataclasses import dataclass, field

from . import gpu as gpumod

SYS = "/sys/class"


def _read(path: str) -> str | None:
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def _read_int(path: str) -> int | None:
    v = _read(path)
    try:
        return int(v) if v is not None else None
    except ValueError:
        return None


# ------------------------------------------------------------- hwmon -------

@dataclass
class Fan:
    label: str
    input_path: str
    max_rpm: int | None
    boost_path: str | None
    unit: str = "RPM"           # MSI (msi-ec) informa en porcentaje


def msi_fans(root: str = "/") -> list[Fan]:
    """MSI con msi-ec: velocidad de los ventiladores en % (no en hwmon)."""
    out = []
    base = os.path.join(root, "sys/devices/platform/msi-ec")
    for part, label in (("cpu", "CPU Fan"), ("gpu", "GPU Fan")):
        path = f"{base}/{part}/realtime_fan_speed"
        if os.path.exists(path):
            out.append(Fan(label, path, 100, None, unit="%"))
    return out


@dataclass
class Capabilities:
    vendor_driver: str = ""
    cpu_name: str = ""
    model: str = ""             # p. ej. "Alienware 16X Aurora"
    brand: str = ""             # fabricante del portátil, en minúsculas ("alienware", "asus"...)
    cpu_vendor: str = ""        # "intel" | "amd"
    gpu_name: str = ""
    gpu_kind: str = ""
    gpu_discrete: bool = False
    profile_manager: str = ""   # "tlp" / "auto-cpufreq" si sustituyen a power-profiles
    fans: list[Fan] = field(default_factory=list)
    platform_profile: str | None = None  # ruta al nodo platform-profile
    power_profiles_dbus: bool = False
    battery: str | None = None
    charge_threshold: str | None = None  # interfaz estándar power_supply
    firmware_battery: bool = False  # p.ej. Dell dell-wmi-sysman (requiere root)
    cpu_temp_path: str | None = None


def _cpu_name() -> str:
    for line in (_read("/proc/cpuinfo") or "").splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1].strip()
            for junk in ("Intel(R) ", "Core(TM) ", "AMD ", " Processor", "(R)", "(TM)"):
                name = name.replace(junk, "")
            return " ".join(name.split())
    return "CPU"


# Desarrollo: VORTICE_SIMULATE="no-gpu,gpu-asleep,no-ppd,tlp,no-fans,no-battery,kbd-brightness"
SIMULATE = set(filter(None, os.environ.get("VORTICE_SIMULATE", "").split(",")))


def detect() -> Capabilities:
    caps = Capabilities(cpu_name=_cpu_name())
    vendor = _read("/sys/class/dmi/id/sys_vendor") or ""
    product = _read("/sys/class/dmi/id/product_name") or ""
    # "Alienware 16X Aurora AC16251": quita el código de modelo final si va en mayúsculas+cifras.
    parts = product.split()
    if len(parts) > 1 and any(ch.isdigit() for ch in parts[-1]) and parts[-1].isupper():
        parts = parts[:-1]
    product = " ".join(parts)
    caps.model = product if product.lower().startswith(vendor.lower()) else f"{vendor} {product}".strip()
    caps.brand = vendor.lower()
    cpuinfo = _read("/proc/cpuinfo") or ""
    caps.cpu_vendor = "intel" if "GenuineIntel" in cpuinfo else "amd" if "AuthenticAMD" in cpuinfo else ""

    for hw in sorted(glob.glob(f"{SYS}/hwmon/hwmon*")):
        name = _read(f"{hw}/name") or ""
        # Temperatura de CPU: coretemp (Intel) / k10temp (AMD), paquete completo.
        if name in ("coretemp", "k10temp", "zenpower") and not caps.cpu_temp_path:
            for lbl in glob.glob(f"{hw}/temp*_label"):
                if _read(lbl) in ("Package id 0", "Tctl", "Tdie"):
                    caps.cpu_temp_path = lbl.replace("_label", "_input")
                    break
        # Ventiladores: cualquier driver de plataforma con fanN_input.
        for fin in sorted(glob.glob(f"{hw}/fan*_input")):
            base = fin[: -len("_input")]
            label = _read(f"{base}_label") or os.path.basename(base)
            boost = f"{base}_boost" if os.path.exists(f"{base}_boost") else None
            # Evita duplicados (dell_smm repite lo que ya da alienware_wmi).
            if any(f.label == label for f in caps.fans):
                continue
            if name in ("dell_smm", "dell_ddv") and caps.fans:
                continue
            caps.fans.append(Fan(label, fin, _read_int(f"{base}_max"), boost))
            if not caps.vendor_driver and name not in ("dell_smm", "dell_ddv"):
                caps.vendor_driver = name

    if not caps.fans:
        caps.fans = msi_fans()
        if caps.fans:
            caps.vendor_driver = caps.vendor_driver or "msi-ec"

    pp = sorted(glob.glob(f"{SYS}/platform-profile/platform-profile-*"))
    if pp:
        caps.platform_profile = pp[0]
        caps.vendor_driver = caps.vendor_driver or (_read(f"{pp[0]}/name") or "")

    caps.power_profiles_dbus = _ppd_call("get") is not None
    if not caps.power_profiles_dbus:
        for tool, paths in (("TLP", ("/usr/sbin/tlp", "/usr/bin/tlp")),
                            ("auto-cpufreq", ("/usr/bin/auto-cpufreq", "/usr/local/bin/auto-cpufreq"))):
            if any(os.path.exists(x) for x in paths):
                caps.profile_manager = tool
                break

    for bat in sorted(glob.glob(f"{SYS}/power_supply/BAT*")):
        caps.battery = bat
        if os.path.exists(f"{bat}/charge_control_end_threshold"):
            caps.charge_threshold = f"{bat}/charge_control_end_threshold"
        break
    caps.firmware_battery = bool(
        glob.glob(f"{SYS}/firmware-attributes/*/attributes/PrimaryBattChargeCfg")
    )
    if "no-ppd" in SIMULATE or "tlp" in SIMULATE:
        caps.power_profiles_dbus = False
        caps.profile_manager = "TLP" if "tlp" in SIMULATE else ""
    if "no-fans" in SIMULATE:
        caps.fans = []
    if "no-battery" in SIMULATE:
        caps.battery = caps.charge_threshold = None
        caps.firmware_battery = False
    return caps


# ------------------------------------------------- power-profiles (D-Bus) --

_PPD = ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles")


def _ppd_call(action: str, value: str = "") -> str | None:
    """Habla con power-profiles-daemon / tuned-ppd por D-Bus. No toca sysfs a mano,
    para no pelearse con lo que gestiona la distro (tuned en Bazzite)."""
    from . import dbus
    if action == "get":
        v = dbus.get_property(dbus.PPD, "ActiveProfile")
        return str(v) if v else None
    return value if dbus.set_property(dbus.PPD, "ActiveProfile", value) else None


def get_profile() -> str | None:
    return _ppd_call("get")


def get_profile_details(caps: "Capabilities") -> dict:
    """Qué hay debajo del modo: perfil de tuned (si existe) y modo del firmware."""
    out = {}
    if caps.platform_profile:
        out["firmware"] = _read(f"{caps.platform_profile}/profile") or ""
        out["firmwareDriver"] = _read(f"{caps.platform_profile}/name") or ""
    from . import dbus
    ok, val = dbus.call(dbus.TUNED, "active_profile")
    if ok and val:
        out["tuned"] = str(val)
    return out


def set_profile(name: str) -> bool:
    return _ppd_call("set", name) is not None


# --------------------------------------------------------------- lectura ---

class Sampler:
    """Toma muestras periódicas. Guarda estado para calcular uso de CPU."""

    def __init__(self, caps: Capabilities) -> None:
        self.caps = caps
        gpus = [] if "no-gpu" in SIMULATE else gpumod.detect()
        self.gpu = gpus[0] if gpus else None
        if self.gpu:
            caps.gpu_name = self.gpu.name
            caps.gpu_kind = self.gpu.kind
            caps.gpu_discrete = self.gpu.discrete
        self._prev_cpu: tuple[int, int] | None = None

    def _cpu_usage(self) -> float | None:
        line = (_read("/proc/stat") or "").splitlines()[0].split()[1:]
        vals = [int(x) for x in line]
        idle, total = vals[3] + vals[4], sum(vals)
        prev, self._prev_cpu = self._prev_cpu, (idle, total)
        if not prev or total == prev[1]:
            return None
        return 100.0 * (1 - (idle - prev[0]) / (total - prev[1]))

    @staticmethod
    def _cpu_freq() -> float | None:
        freqs = [
            _read_int(p)
            for p in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq")
        ]
        freqs = [f for f in freqs if f]
        return max(freqs) / 1e6 if freqs else None  # GHz, núcleo más rápido

    def sample(self) -> dict:
        c = self.caps
        s: dict = {"t": time.time()}

        temp = _read_int(c.cpu_temp_path) if c.cpu_temp_path else None
        s["cpu"] = {
            "temp": temp / 1000 if temp else None,
            "util": self._cpu_usage(),
            "freq": self._cpu_freq(),
        }
        s["gpu"] = self.gpu.sample() if self.gpu else {}
        if "gpu-asleep" in SIMULATE and self.gpu:
            s["gpu"] = {"asleep": True}

        s["fans"] = []
        for f in c.fans:
            rpm = _read_int(f.input_path) or 0
            s["fans"].append({
                "label": f.label,
                "rpm": rpm,
                "max": f.max_rpm or 6000,
                "unit": f.unit,
                "boost": _read_int(f.boost_path) if f.boost_path else None,
            })

        if c.battery:
            b = c.battery
            s["battery"] = {
                "capacity": _read_int(f"{b}/capacity"),
                "status": _read(f"{b}/status"),
                "limit": _read_int(c.charge_threshold) if c.charge_threshold else None,
            }
        s["ac"] = _read_int(f"{SYS}/power_supply/AC/online") == 1
        return s


if __name__ == "__main__":
    import json

    caps = detect()
    sm = Sampler(caps)
    sm.sample()
    time.sleep(0.5)
    print(json.dumps({"caps": caps.__dict__ | {"fans": [f.__dict__ for f in caps.fans]},
                      "profile": get_profile(), "sample": sm.sample()},
                     indent=2, default=str, ensure_ascii=False))


# ------------------------------------------------ servicio privilegiado ----

_HELPER = ("io.github.vortice.Helper", "/io/github/vortice/Helper1", "io.github.vortice.Helper1")


def helper_call(method: str, signature: str = "", *args) -> tuple[bool, object]:
    """Llama al servicio root de Vórtice por D-Bus. Devuelve (ok, datos | error).
    `signature` se conserva por compatibilidad: QtDBus deduce los tipos (s / i)."""
    from . import dbus
    conv = [int(a) if t == "i" else str(a) for t, a in zip(signature, args)] if signature else list(args)
    ok, val = dbus.call(dbus.HELPER, method, *conv)
    if not ok:
        msg = str(val)
        if "ServiceUnknown" in msg or "was not provided" in msg or "not activatable" in msg.lower():
            msg = "el servicio de Vórtice no está instalado"
        return False, msg
    return True, val


def helper_state() -> dict | None:
    import json

    ok, data = helper_call("GetState")
    return json.loads(data) if ok and isinstance(data, str) else None
