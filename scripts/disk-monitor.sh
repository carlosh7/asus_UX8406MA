#!/bin/bash
# Disk Space Monitor - ASUS Zenbook Duo UX8406MA
# Checks disk usage every hour, sends desktop notification if > 80%

THRESHOLD_WARN=80
THRESHOLD_CRIT=90
LOG="/var/log/disk-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check root partition
ROOT_USAGE=$(df / --output=pcent | tail -1 | tr -d '% ')
HOME_USAGE=$(df /home --output=pcent | tail -1 | tr -d '% ')

# Log
echo "[$DATE] Root: ${ROOT_USAGE}%, Home: ${HOME_USAGE}%" >> "$LOG"

# Keep log under 1000 lines
tail -1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# Find the active GUI user and UID dynamically
GUI_USER=$(logname 2>/dev/null || who | awk "{print \$1}" | head -n1 || echo "")
if [ -z "$GUI_USER" ]; then
    # Fallback to the first directory under /run/user/ (excluding root/0)
    USER_ID=$(find /run/user -mindepth 1 -maxdepth 1 -type d -not -name "0" -exec basename {} \; 2>/dev/null | head -n 1)
    if [ -n "$USER_ID" ]; then
        GUI_USER=$(getent passwd "$USER_ID" | cut -d: -f1)
    fi
fi
if [ -z "$GUI_USER" ]; then
    GUI_USER="root"
fi
GUI_UID=$(id -u "$GUI_USER" 2>/dev/null || echo "1000")

# Alert if over threshold
if [ "$ROOT_USAGE" -gt "$THRESHOLD_CRIT" ]; then
    # Desktop notification
    sudo -u "$GUI_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$GUI_UID/bus \
        notify-send -u critical "DISCO CRÍTICO" \
        "Raíz al ${ROOT_USAGE}% - ¡Limpieza urgente necesaria!" 2>/dev/null || true
elif [ "$ROOT_USAGE" -gt "$THRESHOLD_WARN" ]; then
    sudo -u "$GUI_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$GUI_UID/bus \
        notify-send -u normal "DISCO LLENO" \
        "Raíz al ${ROOT_USAGE}% - Considera limpiar espacio" 2>/dev/null || true
fi
