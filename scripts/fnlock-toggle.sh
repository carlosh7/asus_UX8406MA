#!/bin/bash
# ============================================================================
# Alterna la personalidad de la fila superior del teclado:
#   Multimedia <-> Teclas de función (F1-F12)
# Persistente entre reconexiones. Notificación OSD del modo resultante.
#
# Invocable como usuario normal o como root (mapper/systemd): hace drop a la
# sesión gráfica y GARANTIZA el entorno D-Bus antes de notificar.
# ============================================================================

MODE_FILE="/etc/zenbook-duo/fnlock-mode"

# --- Garantizar entorno de sesión para notify-send --------------------------
ensure_session_env() {
    local u="${SUDO_USER:-}"
    if [ "$(id -u)" -eq 0 ]; then
        if [ -z "$u" ]; then
            u=$(loginctl list-sessions --no-legend 2>/dev/null | while read -r sid _rest; do
                t=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
                [ "$t" = "wayland" ] || [ "$t" = "x11" ] && { loginctl show-session "$sid" -p Name --value; break; }
            done)
        fi
        [ -z "$u" ] && return 1
        export SUDO_USER="$u"
    else
        u=$(id -un)
    fi
    local uid
    uid=$(id -u "$u")
    if [ -S "/run/user/${uid}/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus"
        export XDG_RUNTIME_DIR="/run/user/${uid}"
        export HOME="$(getent passwd "$u" | cut -d: -f6)"
    fi
    return 0
}

notify_mode() {
    ensure_session_env || return 0
    notify-send -t 2000 -a 'Zenbook Duo' "$1" \
        "Guardado automáticamente para USB y Bluetooth" 2>/dev/null || \
    echo "(no se pudo mostrar notificación)"
}

# --- Si venimos como root, re-ejecutar como usuario de sesión ---------------
if [ "$(id -u)" -eq 0 ]; then
    ensure_session_env
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        exec sudo -u "$SUDO_USER" \
            DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" \
            XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
            HOME="${HOME}" \
            "$0" "$@"
    fi
fi

# --- Alternar ---------------------------------------------------------------
CUR=$(cat "$MODE_FILE" 2>/dev/null || echo 0)
[ "$CUR" != "1" ] && CUR=0
NEW=$((1 - CUR))

if ! /usr/local/bin/fn-lock.py "$NEW"; then
    notify_mode 'Error' 
    exit 1
fi

if [ "$NEW" = "1" ]; then
    notify_mode "Fila de teclas: F1-F12"
else
    notify_mode "Fila de teclas: Multimedia"
fi
