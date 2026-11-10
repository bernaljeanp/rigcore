"""Pruebas de la lógica del agente de perfiles por juego (sin tocar el sistema)."""

import unittest
from unittest import mock

from vortice import agent


class FakeSystem:
    def __init__(self):
        self.profile = "balanced"
        self.boost = 0
        self.ac = True
        self.running = []

    def patch(self, test):
        for name, fn in (("get_profile", lambda: self.profile),
                         ("set_profile", self._set_profile),
                         ("set_boost", self._set_boost),
                         ("on_ac", lambda: self.ac),
                         ("write_json_atomic", lambda *a: None)):
            p = mock.patch.object(agent, name, fn)
            p.start()
            test.addCleanup(p.stop)

    def _set_profile(self, name):
        self.profile = name
        return True

    def _set_boost(self, value):
        self.boost = value
        return True


class AgentTests(unittest.TestCase):
    def setUp(self):
        self.sys = FakeSystem()
        self.sys.patch(self)
        self.a = agent.Agent()
        self.a.cfg.reload_if_changed = lambda: None
        self.a.cfg.data = {**agent.DEFAULT_CONFIG, "games": {
            "steam:730": {"mode": "performance", "boost": 128},
            "steam:999": {"mode": "none"},          # "sin cambios"
        }}
        self.a.scan.running = lambda procs: list(self.sys.running)

    def tick(self, running=None):
        if running is not None:
            self.sys.running = running
        self.a.tick()

    def test_abre_y_cierra_juego(self):
        self.tick(["steam:730"])
        self.assertEqual((self.sys.profile, self.sys.boost), ("performance", 128))
        self.tick([])
        self.assertEqual((self.sys.profile, self.sys.boost), ("balanced", 0))

    def test_respeta_cambio_manual_durante_la_partida(self):
        self.tick(["steam:730"])
        self.sys.profile = "power-saver"      # el usuario lo cambia a mano
        self.tick([])
        self.assertEqual(self.sys.profile, "power-saver")
        self.assertEqual(self.sys.boost, 0)    # el boost sí se devuelve a automático

    def test_juego_sin_perfil_usa_el_predeterminado(self):
        self.tick(["steam:123"])
        self.assertEqual((self.sys.profile, self.sys.boost), ("performance", 0))

    def test_sin_cambios_no_toca_nada(self):
        self.tick(["steam:999"])
        self.assertEqual(self.sys.profile, "balanced")
        self.assertIsNone(self.a.active)

    def test_solo_con_cargador(self):
        self.sys.ac = False
        self.tick(["steam:730"])
        self.assertEqual(self.sys.profile, "balanced")
        self.sys.ac = True
        self.tick()
        self.assertEqual(self.sys.profile, "performance")
        self.sys.ac = False                    # desenchufa en mitad de la partida
        self.tick()
        self.assertEqual((self.sys.profile, self.sys.boost), ("balanced", 0))

    def test_desactivado_no_actua(self):
        self.a.cfg.data["enabled"] = False
        self.tick(["steam:730"])
        self.assertEqual(self.sys.profile, "balanced")

    def test_cambio_de_perfil_en_caliente(self):
        self.tick(["steam:730"])
        self.a.cfg.data["games"]["steam:730"] = {"mode": "balanced", "boost": 0}
        self.tick()
        self.assertEqual((self.sys.profile, self.sys.boost), ("balanced", 0))

    def test_prioriza_juego_con_perfil_propio(self):
        self.tick(["steam:123", "steam:730"])
        self.assertEqual(self.a.active, "steam:730")


class ScannerTests(unittest.TestCase):
    def test_identifica_steam_por_reaper(self):
        files = {"/proc/42/comm": "reaper\n",
                 "/proc/42/cmdline": b"reaper\0SteamLaunch\0AppId=730\0--\0/x/cs2\0"}

        def fake_open(path, mode="r"):
            data = files[path]
            return mock.mock_open(read_data=data)()

        with mock.patch("builtins.open", fake_open):
            self.assertEqual(agent.Scanner.identify(42, set()), "steam:730")

    def test_identifica_proceso_configurado(self):
        with mock.patch("builtins.open", mock.mock_open(read_data="sober\n")):
            self.assertEqual(agent.Scanner.identify(7, {"sober"}), "proc:sober")


if __name__ == "__main__":
    unittest.main()
