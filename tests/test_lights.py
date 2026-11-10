"""Pruebas del protocolo de luces (sin hardware)."""

import os
import tempfile
import unittest

from vortice import lights

# Descriptor HID mínimo: Report Size 8 (0x75 0x08), Report Count 33 (0x95 0x21), Output (0x91 0x02).
DESC_33 = bytes([0x75, 0x08, 0x95, 0x21, 0x91, 0x02])


class ProtocolTests(unittest.TestCase):
    def test_tamano_reporte(self):
        self.assertEqual(lights.output_report_size(DESC_33), 33)

    def test_color_fijo(self):
        seq = lights.reports("static", "FFB020", 80)
        self.assertTrue(all(len(r) == 34 and r[0] == 0 for r in seq))
        color = next(r for r in seq if r[2] == 0x27)
        self.assertEqual(tuple(color[3:6]), (0xFF, 0xB0, 0x20))
        dim = seq[-1]
        self.assertEqual((dim[2], dim[3]), (0x26, 20))   # atenuación = 100 - brillo

    def test_apagado_atenua_al_maximo(self):
        self.assertEqual(lights.reports("off", "FFFFFF", 70)[-1][3], 100)

    def test_aurora_usa_transiciones(self):
        seq = lights.reports("aurora", "000000", 100)
        acts = [r for r in seq if r[2] == 0x24]
        self.assertEqual(len(acts), 2)                    # 6 colores, 3 por reporte
        self.assertEqual(acts[0][3], 2)                   # tipo de acción: transición

    def test_respirar_alterna_color_y_negro(self):
        act = next(r for r in lights.reports("breathe", "112233", 100) if r[2] == 0x24)
        self.assertEqual(tuple(act[8:11]), (0x11, 0x22, 0x33))
        self.assertEqual(tuple(act[16:19]), (0, 0, 0))

    def test_valida_entradas(self):
        for bad in (("disco", "FFFFFF", 50), ("static", "GGGGGG", 50), ("static", "FFF", 50),
                    ("static", "FFFFFF", 101)):
            with self.assertRaises(ValueError):
                lights.reports(*bad)


class DetectionTests(unittest.TestCase):
    def test_encuentra_el_controlador_alienware(self):
        with tempfile.TemporaryDirectory() as root:
            for n, (hid, desc) in enumerate([("0003:0000248A:00005B2E", DESC_33),      # ratón
                                             ("0003:0000187C:00000551", DESC_33)]):   # AW-ELC
                d = os.path.join(root, f"sys/class/hidraw/hidraw{n}/device")
                os.makedirs(d)
                with open(f"{d}/uevent", "w") as f:
                    f.write(f"HID_ID={hid}\nHID_NAME=Dispositivo {n}\n")
                with open(f"{d}/report_descriptor", "wb") as f:
                    f.write(desc)
            ctrl = lights.find_controller(root)
            self.assertEqual(ctrl["path"], "/dev/hidraw1")


if __name__ == "__main__":
    unittest.main()


class OtrasMarcasTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def w(self, rel, value=""):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(str(value))
        return path

    def r(self, rel):
        with open(os.path.join(self.root, rel)) as f:
            return f.read().strip()

    def test_asus(self):
        led = "sys/class/leds/asus::kbd_backlight"
        self.w(f"{led}/kbd_rgb_mode"); self.w(f"{led}/brightness", 0); self.w(f"{led}/max_brightness", 3)
        c = lights.detect(self.root)
        self.assertEqual(c["kind"], "asus")
        lights.apply_any("breathe", "FF8000", 100, c)
        self.assertEqual(self.r(f"{led}/kbd_rgb_mode"), "0 1 255 128 0 1")   # sin guardar en la BIOS
        self.assertEqual(self.r(f"{led}/brightness"), "3")
        lights.apply_any("off", "FF8000", 100, c)
        self.assertEqual(self.r(f"{led}/brightness"), "0")

    def test_acer_4_zonas(self):
        base = lights.ACER_BASE
        self.w(f"{base}/per_zone_mode", ""); self.w(f"{base}/four_zone_mode", "")
        c = lights.detect(self.root)
        self.assertEqual(c["kind"], "acer4")
        lights.apply_any("static", "4287F5", 60, c)
        self.assertEqual(self.r(f"{base}/per_zone_mode"), "4287f5,4287f5,4287f5,4287f5,60")
        lights.apply_any("breathe", "FF0000", 80, c)
        self.assertEqual(self.r(f"{base}/four_zone_mode"), "1,4,80,1,255,0,0")

    def test_multicolor_respeta_el_orden(self):
        led = "sys/class/leds/rgb:kbd_backlight"
        self.w(f"{led}/multi_index", "green blue red"); self.w(f"{led}/multi_intensity", "0 0 0")
        self.w(f"{led}/brightness", 0); self.w(f"{led}/max_brightness", 255)
        c = lights.detect(self.root)
        self.assertEqual(c["kind"], "multicolor")
        lights.apply_any("static", "112233", 100, c)
        self.assertEqual(self.r(f"{led}/multi_intensity"), "34 51 17")      # verde azul rojo
        self.assertEqual(self.r(f"{led}/brightness"), "255")

    def test_solo_brillo_y_efecto_no_soportado(self):
        led = "sys/class/leds/tpacpi::kbd_backlight"
        self.w(f"{led}/brightness", 0); self.w(f"{led}/max_brightness", 2)
        c = lights.detect(self.root)
        self.assertEqual((c["kind"], c["color"]), ("brightness", False))
        out = lights.apply_any("aurora", "FFFFFF", 50, c)                 # no soportado: fijo
        self.assertEqual(out["effect"], "static")
        self.assertEqual(self.r(f"{led}/brightness"), "1")

    def test_sin_teclado_iluminado(self):
        self.assertIsNone(lights.detect(self.root))
