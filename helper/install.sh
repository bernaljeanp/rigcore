#!/bin/sh
# Instala (o desinstala con --uninstall) el servicio privilegiado de Vórtice.
# Uso: sudo ./helper/install.sh   |   sudo ./helper/install.sh --uninstall
set -eu

[ "$(id -u)" -eq 0 ] || { echo "Ejecuta con sudo." >&2; exit 1; }
SRC=$(dirname "$(readlink -f "$0")")

LIBEXEC=/usr/local/libexec/vortice
UNIT=/etc/systemd/system/vortice-helper.service
POLICY=/etc/dbus-1/system.d/io.github.vortice.Helper.conf

if [ "${1:-}" = "--uninstall" ]; then
    systemctl disable --now vortice-helper.service 2>/dev/null || true
    rm -f "$UNIT" "$POLICY"
    rm -rf "$LIBEXEC"
    systemctl daemon-reload
    echo "Servicio de Vórtice desinstalado."
    exit 0
fi

# El servicio usa el Python del sistema con GLib (python3-gobject / python3-gi).
if ! /usr/bin/python3 -c "from gi.repository import Gio" 2>/dev/null; then
    echo "Falta PyGObject. Instálalo con el gestor de tu distro:" >&2
    echo "  Fedora: dnf install python3-gobject   Debian/Ubuntu: apt install python3-gi" >&2
    echo "  Arch/CachyOS: pacman -S python-gobject" >&2
    exit 1
fi
# Copias propiedad de root: el código privilegiado no se ejecuta desde /home.
install -d -o root -g root -m 0755 "$LIBEXEC"
install -o root -g root -m 0755 "$SRC/vortice-helper" "$LIBEXEC/vortice-helper"
# Política D-Bus solo con los grupos de administración que existen aquí
# (un grupo inexistente puede invalidar el archivo en algunos buses).
BLOCKS=""
for g in wheel sudo admin; do
    getent group "$g" >/dev/null || continue
    BLOCKS="$BLOCKS  <policy group=\"$g\">
    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"io.github.vortice.Helper1\"/>
    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Introspectable\"/>
    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Properties\"/>
    <allow send_destination=\"io.github.vortice.Helper\" send_interface=\"org.freedesktop.DBus.Peer\"/>
  </policy>
"
done
[ -n "$BLOCKS" ] || { echo "No hay grupo de administradores (wheel/sudo/admin)." >&2; exit 1; }
TMP=$(mktemp)
awk -v blocks="$BLOCKS" '{ if ($0 ~ /@ADMIN_POLICIES@/) printf "%s", blocks; else print }' \
    "$SRC/io.github.vortice.Helper.conf" > "$TMP"
install -o root -g root -m 0644 "$TMP" "$POLICY"
rm -f "$TMP"
install -o root -g root -m 0644 "$SRC/vortice-helper.service" "$UNIT"
command -v restorecon >/dev/null && restorecon -R "$LIBEXEC" "$UNIT" "$POLICY" || true

systemctl reload dbus.service 2>/dev/null || busctl call org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null
systemctl daemon-reload
systemctl enable --now vortice-helper.service
systemctl restart vortice-helper.service
sleep 1
systemctl --no-pager --lines=5 status vortice-helper.service
echo
echo "Listo. Servicio de Vórtice instalado y activo."
