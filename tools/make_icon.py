"""Genera el icono de Rigcore: mando con una turbina en lugar de la cruceta.

El mando dice "gaming"; la turbina, que la app controla el equipo (ventiladores,
modos, luces). Solo el mando, sin placa: blanco con un contorno grafito fino
(para que se vea también sobre fondos claros) y rosa de señal.
Uso:
    python tools/make_icon.py > rigcore/qml/icon.svg
    python tools/make_icon.py --symbolic > rigcore/qml/icon-symbolic.svg
"""

import math
import sys

GRAPHITE, WHITE, PINK = "#121315", "#F4F1EC", "#FF3E8E"

# El mando ocupa y=152..412: el viewBox se desplaza para centrarlo en vertical.
VIEWBOX = "0 26 512 512"
PAD = ("M176 152H336C392 152 428 184 444 240L472 340C484 384 456 412 420 404"
       "C396 398 380 380 364 356L344 328H168L148 356C132 380 116 398 92 404"
       "C56 412 28 384 40 340L68 240C84 184 120 152 176 152Z")
VX, VY = 168, 236          # centro de la turbina (donde iría la cruceta)
WELL = 54                  # hueco de la turbina
BUTTONS = [(352, 204), (352, 268), (320, 236)]   # huecos; el cuarto va en rosa
PINK_BTN = (384, 236)
BTN_R = 14


def blade(a0: float, hub: float, reach: float, n: int = 60) -> list[tuple[float, float]]:
    """Aspa curvada entre dos espirales que convergen en la punta."""
    lead, trail = [], []
    for i in range(n + 1):
        s = i / n
        r = hub + (reach - hub) * s
        a = a0 - 1.2 * s ** 1.2
        w = 1.25 * (1 - s) ** 0.8 + 0.06
        lead.append((r, a))
        trail.append((r, a + w))
    poly = lead + trail[::-1]
    return [(VX + r * math.cos(a), VY + r * math.sin(a)) for r, a in poly]


def to_d(poly) -> str:
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in poly) + " Z"


def circle_d(cx, cy, r) -> str:
    return f"M{cx - r} {cy}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z"


blades = " ".join(to_d(blade(-math.pi / 2 + k * 2 * math.pi / 3, 8, 44)) for k in range(3))
hub = circle_d(VX, VY, 11)

if "--symbolic" in sys.argv:
    # Bandeja: un solo color que Plasma cambia por el del tema. Mando con huecos
    # (evenodd) y la turbina dentro del hueco grande.
    holes = circle_d(VX, VY, WELL) + "".join(circle_d(x, y, BTN_R) for x, y in BUTTONS + [PINK_BTN])
    print(f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}">
  <defs><style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#232629; }}</style></defs>
  <path class="ColorScheme-Text" fill="currentColor" fill-rule="evenodd" d="{PAD} {holes}"/>
  <path class="ColorScheme-Text" fill="currentColor" d="{blades} {hub}"/>
</svg>""")
    sys.exit()

holes = "".join(f'<circle cx="{x}" cy="{y}" r="{BTN_R}" fill="{GRAPHITE}"/>' for x, y in BUTTONS)
print(f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}">
  <path fill="{WHITE}" stroke="{GRAPHITE}" stroke-width="12" stroke-linejoin="round" d="{PAD}"/>
  <circle cx="{VX}" cy="{VY}" r="{WELL}" fill="{GRAPHITE}"/>
  <path fill="{PINK}" d="{blades} {hub}"/>
  {holes}
  <circle cx="{PINK_BTN[0]}" cy="{PINK_BTN[1]}" r="{BTN_R}" fill="{PINK}"/>
</svg>""")
