#!/bin/sh
# Copia los archivos de sistema de Vórtice a un árbol de destino (paquetes de distro).
# Uso: install-files.sh DESTDIR LIBEXECDIR   (p. ej. /usr/lib/vortice o /usr/libexec/vortice)
set -eu
DEST=$1; LIBEXEC=$2
SRC=$(dirname "$(readlink -f "$0")")/..

install -Dm755 "$SRC/helper/vortice-helper" "$DEST$LIBEXEC/vortice-helper"
for m in lights.py fancurve.py fans.py; do
    install -Dm644 "$SRC/vortice/$m" "$DEST$LIBEXEC/$m"
done
sed "s|@LIBEXECDIR@|$LIBEXEC|g" "$SRC/helper/vortice-helper.service" \
    | install -Dm644 /dev/stdin "$DEST/usr/lib/systemd/system/vortice-helper.service"
# Política D-Bus: en Arch y Fedora los administradores son el grupo wheel.
awk '{ if ($0 ~ /@ADMIN_POLICIES@/) {
         print "  <policy group=\"wheel\">"
         print "    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"io.github.vortice.Helper1\"/>"
         print "    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Introspectable\"/>"
         print "    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Properties\"/>"
         print "    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Peer\"/>"
         print "  </policy>"
       } else print }' "$SRC/helper/io.github.vortice.Helper.conf" \
    | install -Dm644 /dev/stdin "$DEST/usr/share/dbus-1/system.d/io.github.vortice.Helper.conf"
install -Dm644 "$SRC/helper/70-vortice-alienware.hwdb" "$DEST/usr/lib/udev/hwdb.d/70-vortice-alienware.hwdb"
install -Dm644 "$SRC/packaging/data/vortice-agent.service" "$DEST/usr/lib/systemd/user/vortice-agent.service"
install -Dm644 "$SRC/packaging/data/vortice.desktop" "$DEST/usr/share/applications/vortice.desktop"
install -Dm644 "$SRC/vortice/qml/icon.svg" "$DEST/usr/share/icons/hicolor/scalable/apps/vortice.svg"
install -Dm644 "$SRC/vortice/qml/icon-symbolic.svg" "$DEST/usr/share/icons/hicolor/scalable/status/vortice-symbolic.svg"
