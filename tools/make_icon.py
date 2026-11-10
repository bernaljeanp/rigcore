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

print(f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="body" gradientUnits="userSpaceOnUse" x1="70" y1="40" x2="440" y2="480">
      <stop offset="0" stop-color="#FFA23D"/>
      <stop offset="0.45" stop-color="#F0386B"/>
      <stop offset="1" stop-color="#7C3AED"/>
    </linearGradient>
    <linearGradient id="sheen" gradientUnits="userSpaceOnUse" x1="0" y1="20" x2="0" y2="300">
      <stop offset="0" stop-color="#fff" stop-opacity="0.40"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="core" gradientUnits="userSpaceOnUse" cx="{C}" cy="{C}" r="{HUB}">
      <stop offset="0.55" stop-color="#2A0B3D" stop-opacity="0.32"/>
      <stop offset="1" stop-color="#2A0B3D" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <path fill-rule="nonzero" fill="url(#body)" d="{silhouette}"/>
  <path fill-rule="nonzero" fill="url(#sheen)" d="{silhouette}"/>
  <circle cx="{C}" cy="{C}" r="{HUB}" fill="url(#core)"/>

  <circle cx="{C}" cy="{C}" r="{HUB - 26}" fill="none" stroke="#FFFFFF" stroke-width="16"/>
  <circle cx="{C}" cy="{C}" r="26" fill="#FFFFFF"/>
</svg>""")
