#!/bin/sh
# Compila los shaders GLSL a .qsb (formato de Qt 6). Requiere requirements-dev.txt.
set -eu
cd "$(dirname "$0")/.."
# QSB: el compilador de shaders de la distro (paquetes) o el de PySide6 (desarrollo).
QSB=${QSB:-$(.venv/bin/python -c "import PySide6, os; print(os.path.join(os.path.dirname(PySide6.__file__), 'qsb'))")}
for f in rigcore/shaders/*.frag; do
    "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
    echo "compilado: $f.qsb"
done
