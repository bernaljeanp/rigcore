#!/bin/sh
# Construye Vortice-x86_64.AppImage (todas las funciones; sin dependencias del sistema
# salvo las bibliotecas gráficas habituales y, para el servicio, PyGObject).
#   packaging/appimage/build.sh            -> build/appimage/Vortice-x86_64.AppImage
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=${WORK:-$ROOT/build/appimage}
PY_VER=3.12.16+20261026
PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-$(printf %s "$PY_VER" | sed 's/+/%2B/')-x86_64-unknown-linux-gnu-install_only.tar.gz"
TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
PYSIDE="PySide6-Essentials==6.12.0"

mkdir -p "$WORK/cache"
cd "$WORK"
[ -s cache/python.tar.gz ] || curl -fL -o cache/python.tar.gz "$PY_URL"
[ -s cache/appimagetool ] || { curl -fL -o cache/appimagetool "$TOOL_URL"; chmod +x cache/appimagetool; }

echo ">> Preparando AppDir"
rm -rf AppDir && mkdir -p AppDir/usr
tar -xzf cache/python.tar.gz -C AppDir/usr          # -> AppDir/usr/python
PY=AppDir/usr/python/bin/python3
"$PY" -m pip install -q --no-compile --disable-pip-version-check "$PYSIDE" "$ROOT"

echo ">> Reduciendo tamaño"
SP=AppDir/usr/python/lib/python3.12
rm -rf "$SP"/test "$SP"/idlelib "$SP"/tkinter "$SP"/turtledemo "$SP"/ensurepip "$SP"/lib2to3 \
       "$SP"/site-packages/pip* "$SP"/../tcl* "$SP"/../tk* AppDir/usr/python/share
PS=$SP/site-packages/PySide6
rm -rf "$PS"/Qt/translations "$PS"/Qt/qml/QtTest "$PS"/Qt/qml/QtQuick/VirtualKeyboard \
       "$PS"/Qt/qml/QtQuick/Scene3D "$PS"/Qt/qml/QtQuick/Scene2D "$PS"/Qt/qml/QtQuick/Pdf \
       "$PS"/Qt/qml/QtQuick/Timeline "$PS"/Qt/qml/QtQuick/Particles "$PS"/Qt/qml/QtQuick/LocalStorage \
       "$PS"/Qt/qml/QtQuick/Dialogs "$PS"/designer "$PS"/assistant "$PS"/linguist "$PS"/lupdate \
       "$PS"/lrelease "$PS"/qmlls "$PS"/qmlformat "$PS"/qmllint "$PS"/qmlcachegen "$PS"/qsb "$PS"/balsam* \
       "$PS"/examples "$PS"/include "$PS"/typesystems "$PS"/glue "$PS"/scripts
find AppDir -name "__pycache__" -type d -prune -exec rm -rf {} +
find AppDir -name "*.pyi" -delete

echo ">> Archivos del servicio, entrada de menú e icono"
mkdir -p AppDir/usr/share/vortice/vortice
cp -r "$ROOT/helper" AppDir/usr/share/vortice/
cp "$ROOT"/vortice/lights.py "$ROOT"/vortice/fancurve.py "$ROOT"/vortice/fans.py AppDir/usr/share/vortice/vortice/
install -m755 "$ROOT/packaging/appimage/AppRun" AppDir/AppRun
cp "$ROOT/packaging/data/vortice.desktop" AppDir/vortice.desktop
cp "$ROOT/vortice/qml/icon.svg" AppDir/vortice.svg
ln -sf vortice.svg AppDir/.DirIcon

echo ">> Empaquetando"
ARCH=x86_64 ./cache/appimagetool --appimage-extract-and-run --no-appstream AppDir Vortice-x86_64.AppImage >/dev/null
ls -lh Vortice-x86_64.AppImage
