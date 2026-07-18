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

# Alert if over threshold
if [ "$ROOT_USAGE" -gt "$THRESHOLD_CRIT" ]; then
    # Desktop notification
    sudo -u carlosh DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        notify-send -u critical "DISCO CRÍTICO" \
        "Raíz al ${ROOT_USAGE}% - ¡Limpieza urgente necesaria!" 2>/dev/null || true
elif [ "$ROOT_USAGE" -gt "$THRESHOLD_WARN" ]; then
    sudo -u carlosh DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        notify-send -u normal "DISCO LLENO" \
        "Raíz al ${ROOT_USAGE}% - Considera limpiar espacio" 2>/dev/null || true
fi
