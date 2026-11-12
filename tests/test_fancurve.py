"""Pruebas de las curvas de ventilador."""

import unittest

from rigcore import fancurve as fc

CURVE = [[50, 0], [70, 0], [80, 40], [90, 100]]


class CurveTests(unittest.TestCase):
    def test_interpolacion(self):
        self.assertEqual(fc.evaluate(CURVE, 40), 0)       # por debajo del primer punto
        self.assertEqual(fc.evaluate(CURVE, 75), 20)      # mitad entre 70 y 80
        self.assertEqual(fc.evaluate(CURVE, 85), 70)
        self.assertEqual(fc.evaluate(CURVE, 99), 100)     # por encima del último

    def test_histeresis_evita_vaivenes(self):
        s = fc.FanState()
        self.assertEqual(s.step(CURVE, 80), 40)
        self.assertEqual(s.step(CURVE, 79), 40)           # baja 1 °C: no cambia
        self.assertEqual(s.step(CURVE, 78), 40)           # 2 °C: tampoco
        self.assertLess(s.step(CURVE, 75), 40)            # 5 °C: ya baja
        self.assertEqual(s.step(CURVE, 90), 100)          # subir es inmediato

    def test_pasos_de_5(self):
        s = fc.FanState()
        self.assertEqual(s.step(CURVE, 73), 10)           # 12 % -> 10 %

    def test_validacion(self):
        ok = fc.validate({"enabled": True, "fans": {"CPU Fan": CURVE}})
        self.assertTrue(ok["enabled"])
        for bad in ({"fans": {"CPU Fan": [[50, 0]]}},                     # un solo punto
                    {"fans": {"CPU Fan": [[70, 0], [60, 50]]}},            # temperaturas al revés
                    {"fans": {"CPU Fan": [[50, 0], [90, 150]]}},           # boost > 100
                    {"fans": {"CPU Fan": [[10, 0], [90, 100]]}},           # temperatura absurda
                    {"fans": {}}, "texto"):
            with self.assertRaises((ValueError, TypeError, IndexError)):
                fc.validate(bad)

    def test_presets_son_validos(self):
        for name, pts in fc.PRESETS.items():
            fc.validate({"fans": {"CPU Fan": pts}})


if __name__ == "__main__":
    unittest.main()
