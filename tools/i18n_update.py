#!/usr/bin/env python3
"""Actualiza y compila la traducción al inglés.

  .venv/bin/python tools/i18n_update.py          extrae textos y compila el .qm
  .venv/bin/python tools/i18n_update.py --check  además, falla si falta alguna traducción

1. pyside6-lupdate extrae los qsTr() de los QML (conserva lo ya traducido).
2. Se añaden al contexto "Vortice" los textos de Python: los tr("...") literales
   y los que pasan por variables (nombres de modos, efectos y avisos de la BIOS).
3. pyside6-lrelease compila vortice/i18n/vortice_en.qm.
Para traducir, edita las etiquetas <translation> de vortice/i18n/vortice_en.ts
(o ábrelo con Qt Linguist) y vuelve a ejecutar este script.
"""

import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "vortice"
TS = PKG / "i18n" / "vortice_en.ts"
QM = PKG / "i18n" / "vortice_en.qm"
BIN = Path(sys.executable).parent

# Textos de Python que llegan a tr() a través de una variable.
DYNAMIC = [
    "Silencioso", "Equilibrado", "Rendimiento", "Fijo", "Respirar", "Aurora", "Apagado",
    "Funciones especiales primero (sin Fn)", "Teclas F1–F12 primero (especiales con Fn)",
    "Fn+Esc activado", "Fn+Esc desactivado", "Guardado en la BIOS",
]


def python_strings():
    found = []
    for py in sorted(PKG.glob("*.py")):
        for m in re.finditer(r'\btr\("((?:[^"\\]|\\.)*)"\)', py.read_text()):
            found.append(m.group(1))
    return list(dict.fromkeys(found + DYNAMIC))


def main():
    TS.parent.mkdir(exist_ok=True)
    qml = sorted(str(p) for p in (PKG / "qml").glob("*.qml"))
    subprocess.run([str(BIN / "pyside6-lupdate"), *qml, "-source-language", "es",
                    "-target-language", "en", "-ts", str(TS)], check=True,
                   stdout=subprocess.DEVNULL)

    tree = ET.parse(TS)
    root = tree.getroot()
    ctx = next((c for c in root.findall("context") if c.findtext("name") == "Vortice"), None)
    if ctx is None:
        ctx = ET.SubElement(root, "context")
        ET.SubElement(ctx, "name").text = "Vortice"
    existing = {m.findtext("source"): m for m in ctx.findall("message")}
    wanted = python_strings()
    for src, m in existing.items():
        # lupdate solo analiza los QML y marca los textos de Python como
        # "vanished"/"obsolete": lrelease los ignoraría. Se rescatan.
        t = m.find("translation")
        if src in wanted and t.get("type") in ("vanished", "obsolete"):
            if (t.text or "").strip():
                t.attrib.pop("type")
            else:
                t.set("type", "unfinished")
    for src in wanted:
        if src not in existing:
            m = ET.SubElement(ctx, "message")
            ET.SubElement(m, "source").text = src
            ET.SubElement(m, "translation", type="unfinished")
    for src, m in existing.items():          # textos de Python que ya no existen
        if src not in wanted:
            ctx.remove(m)
    ET.indent(tree)
    tree.write(TS, encoding="utf-8", xml_declaration=True)

    missing = [m.findtext("source") for c in root.findall("context") for m in c.findall("message")
               if m.find("translation").get("type") in ("unfinished",) or not (m.findtext("translation") or "").strip()]
    missing = [s for s in missing if s is not None]
    subprocess.run([str(BIN / "pyside6-lrelease"), str(TS), "-qm", str(QM)], check=True,
                   stdout=subprocess.DEVNULL)
    total = sum(len(c.findall("message")) for c in root.findall("context"))
    print(f"{total} textos, {total - len(missing)} traducidos, {len(missing)} pendientes -> {QM.name}")
    if missing and "--check" in sys.argv:
        for s in missing:
            print("  falta:", s)
        sys.exit(1)


if __name__ == "__main__":
    main()
