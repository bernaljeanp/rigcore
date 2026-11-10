"""Genera el icono de Vórtice: disco central con tres aspas curvadas en barrido.

Toda la silueta es un único trazado (unión por regla nonzero), así el
degradado y el brillo se aplican sin solapes. Uso:
    python tools/make_icon.py > vortice/qml/icon.svg
"""

import math

C = 256
R = 236        # alcance de las puntas
HUB = 104      # radio del disco central
SWEEP = 1.15   # cuánto se curva cada aspa (radianes)
W0 = 1.55      # anchura angular del aspa en su raíz
N = 120


def blade(a0: float) -> list[tuple[float, float]]:
    """Aspa entre dos espirales que convergen en una punta redondeada."""
    lead, trail = [], []
    for i in range(N + 1):
        s = i / N
        r = HUB * 0.6 + (R - HUB * 0.6) * s
        a = a0 - SWEEP * s ** 1.25
        w = W0 * (1 - s) ** 0.85 + 0.035
        lead.append((r, a))
        trail.append((r, a + w))
    # Punta redondeada: arco entre el final de los dos bordes.
    (r1, a1), (r2, a2) = lead[-1], trail[-1]
    tip = [(R + 2 * math.sin(math.pi * k / 10), a1 + (a2 - a1) * k / 10) for k in range(11)]
    poly = lead + tip + trail[::-1]
    return [(C + r * math.cos(a), C + r * math.sin(a)) for r, a in poly]


def circle(r: float, n: int = 160) -> list[tuple[float, float]]:
    # Mismo sentido de giro que las aspas para que nonzero haga la unión.
    return [(C + r * math.cos(2 * math.pi * k / n), C + r * math.sin(2 * math.pi * k / n))
            for k in range(n)]


def to_d(poly: list[tuple[float, float]]) -> str:
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in poly) + " Z"


def area(poly):  # signo = sentido de giro
    return sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]))


parts = [blade(-math.pi / 2 + k * 2 * math.pi / 3 + 0.55) for k in range(3)]
hub = circle(HUB)
for i, p in enumerate(parts):
    if (area(p) > 0) != (area(hub) > 0):
        parts[i] = p[::-1]
silhouette = " ".join(to_d(p) for p in parts + [hub])

# Estilo "Instrumento": ámbar sólido (el color de señal de la app), ojo en grafito.
AMBER, GRAPHITE = "#FFB020", "#121315"
print(f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <path fill-rule="nonzero" fill="{AMBER}" d="{silhouette}"/>
  <circle cx="{C}" cy="{C}" r="{HUB - 26}" fill="none" stroke="{GRAPHITE}" stroke-width="18"/>
  <circle cx="{C}" cy="{C}" r="24" fill="{GRAPHITE}"/>
</svg>""")
