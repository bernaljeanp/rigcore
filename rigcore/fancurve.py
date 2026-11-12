"""Curvas de ventilador: temperatura -> boost, con histéresis.

Solo biblioteca estándar: lo usa el servicio root (que aplica la curva) y la
interfaz (que la edita y la dibuja).
"""

from __future__ import annotations

import copy

T_MIN, T_MAX = 20, 105
HYSTERESIS = 3.0      # °C que debe bajar la temperatura antes de bajar el ventilador
STEP = 5              # el boost se mueve en pasos de 5 % para no escribir sin parar

PRESETS = {
    "silenciosa":  [[60, 0], [80, 0], [88, 40], [95, 100]],
    "equilibrada": [[50, 0], [70, 0], [80, 40], [90, 100]],
    "agresiva":    [[45, 0], [60, 30], [72, 70], [82, 100]],
}

DEFAULT = {"enabled": False, "linked": True,
           "fans": {"CPU Fan": PRESETS["equilibrada"], "GPU Fan": PRESETS["equilibrada"]}}


def default() -> dict:
    return copy.deepcopy(DEFAULT)


def validate(cfg: dict) -> dict:
    """Devuelve una copia limpia o lanza ValueError con un mensaje claro."""
    if not isinstance(cfg, dict):
        raise ValueError("configuración no válida")
    fans = cfg.get("fans")
    if not isinstance(fans, dict) or not fans or len(fans) > 4:
        raise ValueError("faltan las curvas de los ventiladores")
    out = {"enabled": bool(cfg.get("enabled")), "linked": bool(cfg.get("linked", True)), "fans": {}}
    for label, pts in fans.items():
        if not isinstance(label, str) or len(label) > 32:
            raise ValueError("nombre de ventilador no válido")
        if not isinstance(pts, list) or not 2 <= len(pts) <= 8:
            raise ValueError("cada curva necesita entre 2 y 8 puntos")
        clean = []
        for p in pts:
            t, b = float(p[0]), float(p[1])
            if not (T_MIN <= t <= T_MAX and 0 <= b <= 100):
                raise ValueError(f"punto fuera de rango: {t:.0f} °C, {b:.0f} %")
            if clean and t <= clean[-1][0]:
                raise ValueError("las temperaturas de la curva deben ir en aumento")
            clean.append([round(t, 1), round(b, 1)])
        out["fans"][label] = clean
    return out


def evaluate(points: list, temp: float) -> float:
    """Interpolación lineal; fuera de los extremos se mantiene el valor del extremo."""
    if temp <= points[0][0]:
        return points[0][1]
    for (t0, b0), (t1, b1) in zip(points, points[1:]):
        if temp <= t1:
            return b0 + (b1 - b0) * (temp - t0) / (t1 - t0)
    return points[-1][1]


class FanState:
    """Boost actual de un ventilador según su curva, con histéresis de bajada."""

    def __init__(self) -> None:
        self.pct = 0

    def step(self, points: list, temp: float) -> int:
        up = evaluate(points, temp)
        down = evaluate(points, temp + HYSTERESIS)   # bajar solo si ya sobra margen
        if up > self.pct:
            self.pct = up
        elif down < self.pct:
            self.pct = down
        self.pct = int(round(self.pct / STEP) * STEP)
        return self.pct
