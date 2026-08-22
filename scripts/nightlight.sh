#!/bin/bash
# Night light: GNOME native (Wayland) or Redshift (X11)

STATE_FILE="/tmp/zenbook-nightlight.state"

# Detect the graphical user + session type (works when run as root via systemd)
GRAPHICAL_USER=""
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
SID=$(loginctl list-sessions --no-legend 2>/dev/null | grep " seat0 " | awk '{print $1}' | head -1)
if [ -z "$SID" ]; then
    SID=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$2==1000||$4==1000{print $1; exit}' 2>/dev/null)
    [ -z "$SID" ] && SID=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1; exit}')
fi
if [ -n "$SID" ]; then
    GRAPHICAL_USER=$(loginctl show-session "$SID" -p Name --value 2>/dev/null)
    [ -z "$SESSION_TYPE" ] && SESSION_TYPE=$(loginctl show-session "$SID" -p Type --value 2>/dev/null)
fi

gnome_nightlight() {
    # GNOME native Night Light via gsettings (works on Wayland and X11)
    if [ -z "$GRAPHICAL_USER" ]; then
        echo "No graphical user found" >&2
        return 1
    fi
    # v2: con bus de sesión del usuario (antes escribía en un store fantasma
    # sin DBUS_SESSION_BUS_ADDRESS y nunca aplicaba)
    local uid=$(id -u "$GRAPHICAL_USER")
    sudo -u "$GRAPHICAL_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled "$1" 2>/dev/null
    [ "$1" = "true" ] && sudo -u "$GRAPHICAL_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature "${NIGHTLIGHT_TEMP:-3700}" 2>/dev/null
}

gnome_status() {
    if [ -z "$GRAPHICAL_USER" ]; then
        echo "unknown"
        return
    fi
    local uid=$(id -u "$GRAPHICAL_USER")
    sudo -u "$GRAPHICAL_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        gsettings get org.gnome.settings-daemon.plugins.color night-light-enabled 2>/dev/null
}

case "${1:-toggle}" in
    on|auto)
        if [ "$SESSION_TYPE" = "wayland" ]; then
            gnome_nightlight true
            echo "Night light ON"
        else
            if ! pgrep -x redshift >/dev/null; then
                redshift -m randr -O 3500 &
                echo "Night light ON (3500K)"
            fi
        fi
        ;;
    off)
        if [ "$SESSION_TYPE" = "wayland" ]; then
            gnome_nightlight false
            echo "Night light OFF"
        else
            redshift -x 2>/dev/null
            pkill -x redshift 2>/dev/null
            echo "Night light OFF"
        fi
        ;;
    toggle)
        if [ "$SESSION_TYPE" = "wayland" ]; then
            STATUS=$(gnome_status)
            if [ "$STATUS" = "true" ]; then
                gnome_nightlight false
                echo "Night light OFF"
            else
                gnome_nightlight true
                echo "Night light ON"
            fi
        else
            if pgrep -x redshift >/dev/null; then
                redshift -x 2>/dev/null
                pkill -x redshift 2>/dev/null
                echo "Night light OFF"
            else
                redshift -m randr -O 3500 &
                echo "Night light ON (3500K)"
            fi
        fi
        ;;
    status)
        if [ "$SESSION_TYPE" = "wayland" ]; then
            echo "Night light: $(gnome_status)"
        else
            if pgrep -x redshift >/dev/null; then
                echo "Night light: ON (3500K)"
            else
                echo "Night light: OFF"
            fi
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        ;;
esac
