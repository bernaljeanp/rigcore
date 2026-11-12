#!/bin/sh
# Copia los archivos de sistema de Rigcore a un árbol de destino (paquetes de distro).
# Uso: install-files.sh DESTDIR LIBEXECDIR   (p. ej. /usr/lib/rigcore o /usr/libexec/rigcore)
set -eu
DEST=$1; LIBEXEC=$2
SRC=$(dirname "$(readlink -f "$0")")/..

install -Dm755 "$SRC/helper/rigcore-helper" "$DEST$LIBEXEC/rigcore-helper"
for m in lights.py fancurve.py fans.py; do
    install -Dm644 "$SRC/rigcore/$m" "$DEST$LIBEXEC/$m"
done
sed "s|@LIBEXECDIR@|$LIBEXEC|g" "$SRC/helper/rigcore-helper.service" \
    | install -Dm644 /dev/stdin "$DEST/usr/lib/systemd/system/rigcore-helper.service"
# Política D-Bus: en Arch y Fedora los administradores son el grupo wheel.
awk '{ if ($0 ~ /@ADMIN_POLICIES@/) {
         print "  <policy group=\"wheel\">"
         print "    <allow send_destination=\"io.github.bernaljeanp.Rigcore.Helper\" send_interface=\"io.github.bernaljeanp.Rigcore.Helper1\"/>"
         print "    <allow send_destination=\"io.github.bernaljeanp.Rigcore.Helper\" send_interface=\"org.freedesktop.DBus.Introspectable\"/>"
         print "    <allow send_destination=\"io.github.bernaljeanp.Rigcore.Helper\" send_interface=\"org.freedesktop.DBus.Properties\"/>"
         print "    <allow send_destination=\"io.github.bernaljeanp.Rigcore.Helper\" send_interface=\"org.freedesktop.DBus.Peer\"/>"
         print "  </policy>"
       } else print }' "$SRC/helper/io.github.bernaljeanp.Rigcore.Helper.conf" \
    | install -Dm644 /dev/stdin "$DEST/usr/share/dbus-1/system.d/io.github.bernaljeanp.Rigcore.Helper.conf"
install -Dm644 "$SRC/helper/70-rigcore-alienware.hwdb" "$DEST/usr/lib/udev/hwdb.d/70-rigcore-alienware.hwdb"
install -Dm644 "$SRC/packaging/data/rigcore-agent.service" "$DEST/usr/lib/systemd/user/rigcore-agent.service"
install -Dm644 "$SRC/packaging/data/rigcore.desktop" "$DEST/usr/share/applications/rigcore.desktop"
install -Dm644 "$SRC/rigcore/qml/icon.svg" "$DEST/usr/share/icons/hicolor/scalable/apps/rigcore.svg"
install -Dm644 "$SRC/rigcore/qml/icon-symbolic.svg" "$DEST/usr/share/icons/hicolor/scalable/status/rigcore-symbolic.svg"
