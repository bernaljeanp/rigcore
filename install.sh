#!/bin/sh
# Instalador universal de Vórtice (Bazzite, Silverblue, SteamOS y cualquier distro).
#
#   ./install.sh               instala la app en tu usuario (~/.local) y, si quieres,
#                              el servicio de hardware (pide la contraseña con pkexec)
#   ./install.sh --uninstall   lo quita todo
#
# No necesita rpm-ostree ni cambiar /usr: la app vive en ~/.local/share/vortice.
set -eu

SRC=$(dirname "$(readlink -f "$0")")
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
APP=$DATA/vortice
BIN=$HOME/.local/bin
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}

say() { printf '\033[1m>> %s\033[0m\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
    echo "Ejecuta el instalador con tu usuario normal, sin sudo." >&2
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    systemctl --user disable --now vortice-agent.service 2>/dev/null || true
    rm -f "$CONFIG/systemd/user/vortice-agent.service" "$CONFIG/autostart/vortice.desktop"
    pkill -f "vortice.app --bandeja" 2>/dev/null || true
    rm -rf "$APP"
    rm -f "$BIN/vortice" "$BIN/vortice-agent"
    rm -f "$DATA/applications/vortice.desktop" "$DATA/applications/vortice-teclas.desktop"
    rm -f "$DATA/icons/hicolor/scalable/apps/vortice.svg" "$DATA/icons/hicolor/scalable/status/vortice-symbolic.svg"
    say "App desinstalada (tu configuración en $CONFIG/vortice se conserva)."
    if systemctl is-active --quiet vortice-helper.service 2>/dev/null; then
        say "Quitando el servicio de hardware (pedirá tu contraseña)..."
        pkexec "$SRC/helper/install.sh" --uninstall || true
    fi
    exit 0
fi

command -v python3 >/dev/null || { echo "Falta python3." >&2; exit 1; }
python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' || { echo "Se necesita Python 3.10 o superior." >&2; exit 1; }

say "Creando el entorno de Vórtice en $APP"
python3 -m venv "$APP/venv"
"$APP/venv/bin/pip" install -q --upgrade pip
say "Instalando Vórtice y PySide6 (puede tardar unos minutos la primera vez)..."
"$APP/venv/bin/pip" install -q "$SRC"

mkdir -p "$BIN" "$DATA/applications" "$DATA/icons/hicolor/scalable/apps" "$DATA/icons/hicolor/scalable/status"
cat > "$BIN/vortice" <<EOF
#!/bin/sh
exec "$APP/venv/bin/python" -m vortice.app "\$@"
EOF
cat > "$BIN/vortice-agent" <<EOF
#!/bin/sh
exec /usr/bin/python3 -I "$APP/venv/lib/python$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')/site-packages/vortice/agent.py" "\$@"
EOF
chmod +x "$BIN/vortice" "$BIN/vortice-agent"

sed "s|^Exec=vortice|Exec=$BIN/vortice|" "$SRC/packaging/data/vortice.desktop" > "$DATA/applications/vortice.desktop"
cp "$SRC/vortice/qml/icon.svg" "$DATA/icons/hicolor/scalable/apps/vortice.svg"
cp "$SRC/vortice/qml/icon-symbolic.svg" "$DATA/icons/hicolor/scalable/status/vortice-symbolic.svg"
command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
say "App instalada: búscala como «Vórtice» en el menú, o ejecuta: vortice"

if systemctl is-active --quiet vortice-helper.service 2>/dev/null; then
    say "El servicio de hardware ya está instalado. Actualizándolo (pedirá tu contraseña)..."
    pkexec "$SRC/helper/install.sh" >/dev/null && say "Servicio actualizado."
else
    printf '\n¿Instalar el servicio de hardware (ventiladores, batería, luces persistentes)?\n'
    printf 'Necesita tu contraseña de administrador. [S/n] '
    read -r answer || answer=n
    case "$answer" in
        [nN]*) say "Sin servicio: podrás ver temperaturas y cambiar modos; instálalo luego con: pkexec $SRC/helper/install.sh" ;;
        *) pkexec "$SRC/helper/install.sh" >/dev/null && say "Servicio instalado y activo." ;;
    esac
fi
