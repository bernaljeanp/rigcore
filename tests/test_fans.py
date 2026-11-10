"""Pruebas de control de ventiladores por marca con sysfs simulados."""

import os
import tempfile
import unittest

from vortice import fans


def w(root, rel, value="", mode=0o644):
    path = os.path.join(root, rel.lstrip("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(str(value))
    os.chmod(path, mode)
    return path


def r(root, rel):
    with open(os.path.join(root, rel.lstrip("/"))) as f:
        return f.read().strip()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        fans.ALLOWED_PREFIX = self.root
        # CPU de referencia para la temperatura
        w(self.root, "/sys/class/hwmon/hwmon9/name", "coretemp")
        w(self.root, "/sys/class/hwmon/hwmon9/temp1_label", "Package id 0")
        w(self.root, "/sys/class/hwmon/hwmon9/temp1_input", "60000")

    def tearDown(self):
        fans.ALLOWED_PREFIX = "/sys/"
        self.tmp.cleanup()


class AlienwareTests(Base):
    def test_boost(self):
        h = "/sys/class/hwmon/hwmon5"
        w(self.root, f"{h}/name", "alienware_wmi")
        w(self.root, f"{h}/fan1_input", "2000"); w(self.root, f"{h}/fan1_label", "CPU Fan")
        w(self.root, f"{h}/fan1_boost", "0")
        w(self.root, f"{h}/temp1_label", "CPU"); w(self.root, f"{h}/temp1_input", "70000")
        (f,) = fans.detect(self.root)
        self.assertEqual((f["kind"], f["label"]), ("boost", "CPU Fan"))
        self.assertTrue(f["temp"].endswith("hwmon5/temp1_input"))      # sensor del mismo driver
        fans.Controller().apply(0, f, 128, 70)
        self.assertEqual(r(self.root, f"{h}/fan1_boost"), "128")
        fans.Controller.reset(f)
        self.assertEqual(r(self.root, f"{h}/fan1_boost"), "0")


class DuplicadosTests(Base):
    def test_un_solo_driver_por_ventilador(self):
        # Alienware real: alienware_wmi (boost) y dell_smm (pwm) ven los mismos ventiladores.
        for h, name in (("/sys/class/hwmon/hwmon5", "alienware_wmi"), ("/sys/class/hwmon/hwmon8", "dell_smm")):
            w(self.root, f"{h}/name", name)
            for n, lbl in ((1, "CPU Fan"), (2, "GPU Fan")):
                w(self.root, f"{h}/fan{n}_input", "2000"); w(self.root, f"{h}/fan{n}_label", lbl)
        for n in (1, 2):
            w(self.root, f"/sys/class/hwmon/hwmon5/fan{n}_boost", "0")
            w(self.root, f"/sys/class/hwmon/hwmon8/pwm{n}", "0")
            w(self.root, f"/sys/class/hwmon/hwmon8/pwm{n}_enable", "2")
        found = fans.detect(self.root)
        self.assertEqual([(f["label"], f["kind"]) for f in found], [("CPU Fan", "boost"), ("GPU Fan", "boost")])


class ThinkPadTests(Base):
    def setup_tp(self, allowed):
        h = "/sys/class/hwmon/hwmon3"
        w(self.root, f"{h}/name", "thinkpad")
        w(self.root, f"{h}/fan1_input", "3100")
        w(self.root, f"{h}/pwm1", "0"); w(self.root, f"{h}/pwm1_enable", "2")
        w(self.root, "/sys/module/thinkpad_acpi/parameters/fan_control", "Y" if allowed else "N")
        return h

    def test_sin_fan_control_no_se_toca(self):
        self.setup_tp(False)
        self.assertEqual(fans.detect(self.root), [])

    def test_manual_y_vuelta_a_auto(self):
        h = self.setup_tp(True)
        (f,) = fans.detect(self.root)
        c = fans.Controller()
        self.assertEqual(c.apply(0, f, 150, 60), "pwm 150")
        self.assertEqual((r(self.root, f"{h}/pwm1_enable"), r(self.root, f"{h}/pwm1")), ("1", "150"))
        self.assertEqual(c.apply(0, f, 0, 60), "auto")
        self.assertEqual(r(self.root, f"{h}/pwm1_enable"), "2")

    def test_seguridad_por_temperatura(self):
        self.setup_tp(True)
        (f,) = fans.detect(self.root)
        c = fans.Controller()
        self.assertEqual(c.apply(0, f, 60, 91), "pwm 255")   # a 90 °C o más: máximo
        self.assertEqual(c.apply(0, f, 60, 87), "pwm 255")   # sigue hasta bajar de 85
        self.assertEqual(c.apply(0, f, 60, 84), "pwm 60")


class AsusTests(Base):
    def test_auto_o_maximo(self):
        h = "/sys/class/hwmon/hwmon4"
        w(self.root, f"{h}/name", "asus")
        w(self.root, f"{h}/fan1_input", "2800"); w(self.root, f"{h}/pwm1_enable", "2")
        (f,) = fans.detect(self.root)
        self.assertEqual(f["kind"], "mode")
        self.assertEqual(fans.levels("mode"), ["auto", "max"])
        c = fans.Controller()
        self.assertEqual(c.apply(0, f, 100, 60), "auto")      # por debajo del 80 %: auto
        self.assertEqual(c.apply(0, f, 230, 60), "max")
        self.assertEqual(r(self.root, f"{h}/pwm1_enable"), "0")

    def test_curva_por_hardware(self):
        h = "/sys/class/hwmon/hwmon6"
        w(self.root, f"{h}/name", "asus_custom_fan_curve")
        for k in range(1, 9):
            w(self.root, f"{h}/pwm1_auto_point{k}_temp", "0")
            w(self.root, f"{h}/pwm1_auto_point{k}_pwm", "0")
        w(self.root, f"{h}/pwm1_enable", "2")
        paths = fans.asus_curve_paths(self.root)
        self.assertIn(1, paths)
        self.assertEqual(fans.detect(self.root), [])          # no es un ventilador aparte
        fans.apply_asus_curve(paths, {1: [[50, 0], [70, 0], [80, 40], [90, 100]]})
        temps = [int(r(self.root, f"{h}/pwm1_auto_point{k}_temp")) for k in range(1, 9)]
        pwms = [int(r(self.root, f"{h}/pwm1_auto_point{k}_pwm")) for k in range(1, 9)]
        self.assertEqual((temps[0], temps[-1]), (50, 90))
        self.assertEqual(pwms, sorted(pwms))                   # no decreciente
        self.assertEqual(pwms[-1], 255)
        self.assertEqual(r(self.root, f"{h}/pwm1_enable"), "1")


class HpTests(Base):
    def test_omen_auto_maximo(self):
        h = "/sys/class/hwmon/hwmon7"
        w(self.root, f"{h}/name", "hp")
        w(self.root, f"{h}/fan1_input", "3000"); w(self.root, f"{h}/pwm1_enable", "2")
        w(self.root, f"{h}/pwm1", "0", mode=0o444)            # pwm de solo lectura
        (f,) = fans.detect(self.root)
        self.assertEqual(f["kind"], "mode")

    def test_victus_s_manual(self):
        h = "/sys/class/hwmon/hwmon7"
        w(self.root, f"{h}/name", "hp")
        w(self.root, f"{h}/fan1_input", "3000"); w(self.root, f"{h}/pwm1_enable", "2")
        w(self.root, f"{h}/pwm1", "0", mode=0o644)
        (f,) = fans.detect(self.root)
        self.assertEqual(f["kind"], "pwm")


class MsiTests(Base):
    def test_cooler_boost(self):
        cb = "/sys/devices/platform/msi-ec/cooler_boost"
        w(self.root, cb, "off")
        f, g = fans.detect(self.root)                     # un interruptor, en las dos tarjetas
        self.assertEqual((f["kind"], f["label"], g["label"]), ("toggle", "CPU Fan", "GPU Fan"))
        fans.Controller().apply(0, f, 255, 70)
        self.assertEqual(r(self.root, cb), "on")
        fans.Controller.reset(f)
        self.assertEqual(r(self.root, cb), "off")


class MsiLecturaTests(Base):
    def test_velocidad_en_porcentaje(self):
        from vortice import hardware
        w(self.root, "/sys/devices/platform/msi-ec/cpu/realtime_fan_speed", "45")
        w(self.root, "/sys/devices/platform/msi-ec/gpu/realtime_fan_speed", "60")
        cpu, gpu = hardware.msi_fans(self.root)
        self.assertEqual((cpu.label, cpu.unit, cpu.max_rpm), ("CPU Fan", "%", 100))
        self.assertTrue(gpu.input_path.endswith("gpu/realtime_fan_speed"))


class AcerTests(Base):
    def test_dos_ventiladores_en_un_archivo(self):
        fs = "/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed"
        w(self.root, fs, "0,0")
        cpu, gpu = fans.detect(self.root)
        c = fans.Controller()
        c.apply(0, cpu, 128, 60)
        self.assertEqual(r(self.root, fs), "50,0")
        c.apply(1, gpu, 255, 60)
        self.assertEqual(r(self.root, fs), "50,100")           # conserva el de la CPU
        self.assertEqual(fans.read_value(gpu), 255)
        fans.Controller.reset(cpu)
        self.assertEqual(r(self.root, fs), "0,0")


class ResampleTests(unittest.TestCase):
    def test_ocho_puntos_crecientes(self):
        pts = fans.resample([[60, 0], [95, 100]])
        self.assertEqual(len(pts), 8)
        self.assertEqual([t for t, _ in pts], sorted({t for t, _ in pts}))


if __name__ == "__main__":
    unittest.main()
