#!/bin/sh
# Instala (o desinstala con --uninstall) el servicio privilegiado de Vórtice.
# Uso: sudo ./helper/install.sh   |   sudo ./helper/install.sh --uninstall
set -eu

[ "$(id -u)" -eq 0 ] || { echo "Ejecuta con sudo." >&2; exit 1; }
SRC=$(dirname "$(readlink -f "$0")")

LIBEXEC=/usr/local/libexec/vortice
UNIT=/etc/systemd/system/vortice-helper.service
POLICY=/etc/dbus-1/system.d/io.github.vortice.Helper.conf

HWDB=/etc/udev/hwdb.d/70-vortice-alienware.hwdb
reload_keys() {
    systemd-hwdb update
    # Reaplica el mapa de teclas a los teclados integrados sin reiniciar.
    udevadm trigger --action=change --subsystem-match=input --property-match=ID_INPUT_KEYBOARD=1 || true
    udevadm settle --timeout=10 || true
}

if [ "${1:-}" = "--uninstall" ]; then
    systemctl disable --now vortice-helper.service 2>/dev/null || true
    rm -f "$UNIT" "$POLICY"
    if [ -f "$HWDB" ]; then rm -f "$HWDB"; reload_keys; fi
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
install -o root -g root -m 0644 "$SRC/../vortice/lights.py" "$LIBEXEC/lights.py"
install -o root -g root -m 0644 "$SRC/../vortice/fancurve.py" "$LIBEXEC/fancurve.py"
install -o root -g root -m 0644 "$SRC/../vortice/fans.py" "$LIBEXEC/fans.py"

# Zenit (instalación independiente) también controla las luces: si está, se retira
# con la misma comprobación que usa su propio desinstalador. Sus preferencias
# en /var/lib/zenit se conservan.
ZUNIT=/etc/systemd/system/zenit.service
if [ -f "$ZUNIT" ] && [ ! -L "$ZUNIT" ] && grep -qx 'ExecStart=/usr/bin/python3 /var/opt/zenit/zenit.py demonio\( --solo-luces\)\?' "$ZUNIT"; then
    echo "Retirando el servicio de Zenit para que no compita con Vórtice por las luces..."
    systemctl disable --now zenit.service || true
    rm -f -- "$ZUNIT" /var/opt/zenit/zenit.py
    rmdir /var/opt/zenit 2>/dev/null || true
fi
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

# Teclas especiales de Alienware (F6 Boost, F7 Sigilo): solo en equipos Alienware;
# la regla limita además el modelo, así que en otros no cambia nada.
if [ "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" = "Alienware" ]; then
    install -o root -g root -m 0644 "$SRC/70-vortice-alienware.hwdb" "$HWDB"
    reload_keys
fi
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
