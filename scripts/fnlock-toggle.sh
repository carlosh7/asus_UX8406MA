#!/bin/bash
# ============================================================================
# Alterna la personalidad de la fila superior del teclado:
#   Multimedia (F1=mute, F2/F3=vol...) <-> Teclas de función (F1-F12 reales)
# Muestra notificación con el nuevo modo. Persistente entre reconexiones.
# Llamada habitual: atajo <Super>Esc (registrado en setup-hotkeys.sh)
# ============================================================================

MODE_FILE="/etc/zenbook-duo/fnlock-mode"
CUR=$(cat "$MODE_FILE" 2>/dev/null || echo 0)
[ "$CUR" != "1" ] && CUR=0
NEW=$((1 - CUR))

# Si lo invoca el daemon (root), ejecutar como usuario de sesión para notificar
if [ "$(id -u)" -eq 0 ]; then
    SESSION_USER=$(loginctl list-sessions --no-legend 2>/dev/null | while read -r sid _rest; do
        t=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
        [ "$t" = "wayland" ] || [ "$t" = "x11" ] && { loginctl show-session "$sid" -p Name --value; break; }
    done)
    [ -n "$SESSION_USER" ] && exec sudo -u "$SESSION_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SESSION_USER")/bus" \
        XDG_RUNTIME_DIR="/run/user/$(id -u "$SESSION_USER")" \
        "$0" "$@"
fi

if ! /usr/local/bin/fn-lock.py "$NEW"; then
    notify-send -t 1500 -a 'Zenbook Duo' 'Error' \
        "No se pudo cambiar el modo del teclado" 2>/dev/null
    exit 1
fi

if [ "$NEW" = "1" ]; then
    MSG="Fila de teclas: F1-F12"
else
    MSG="Fila de teclas: Multimedia"
fi

notify-send -t 1500 -a 'Zenbook Duo' "$MSG" \
    "Modo guardado automáticamente para USB y Bluetooth"
