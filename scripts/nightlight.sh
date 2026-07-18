#!/bin/bash
# ============================================================================
# Zenbook Duo - Night Light Controller
# Uses Redshift for blue light filtering on OLED screens
# ============================================================================

CONFIG_FILE="/etc/zenbook-duo/redshift.conf"
STATE_FILE="/tmp/zenbook-nightlight.state"
LOG_FILE="/var/log/zenbook-nightlight.log"

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

is_night() {
    local hour=$(date '+%H')
    local minute=$(date '+%M')
    local current=$((hour * 60 + minute))
    
    local start_hour=19
    local end_hour=6
    local start=$((start_hour * 60))
    local end=$((end_hour * 60))
    
    if [ $current -ge $start ] || [ $current -lt $end ]; then
        return 0  # It's night
    fi
    return 1  # It's day
}

enable_night_light() {
    if pgrep -x redshift >/dev/null; then
        log_msg "Night light already running"
        return
    fi
    
    redshift -c "$CONFIG_FILE" -m randr &
    local pid=$!
    echo "$pid" > "$STATE_FILE"
    log_msg "Night light enabled (PID: $pid)"
}

disable_night_light() {
    if pgrep -x redshift >/dev/null; then
        # Reset colors first
        redshift -x 2>/dev/null
        # Kill redshift
        pkill -x redshift 2>/dev/null
        rm -f "$STATE_FILE"
        log_msg "Night light disabled"
    fi
}

toggle_night_light() {
    if pgrep -x redshift >/dev/null; then
        disable_night_light
    else
        enable_night_light
    fi
}

show_status() {
    if pgrep -x redshift >/dev/null; then
        echo "Night light: ON"
        echo "PID: $(cat $STATE_FILE 2>/dev/null)"
    else
        echo "Night light: OFF"
    fi
    echo "Current time: $(date '+%H:%M')"
    if is_night; then
        echo "Period: Night"
    else
        echo "Period: Day"
    fi
}

case "${1:-toggle}" in
    on|enable)
        enable_night_light
        ;;
    off|disable)
        disable_night_light
        ;;
    toggle)
        toggle_night_light
        ;;
    status)
        show_status
        ;;
    auto)
        # Auto mode: run as daemon, enable/disable based on time
        log_msg "Night light auto-mode started"
        while true; do
            if is_night; then
                if ! pgrep -x redshift >/dev/null; then
                    enable_night_light
                fi
            else
                if pgrep -x redshift >/dev/null; then
                    disable_night_light
                fi
            fi
            sleep 60  # Check every minute
        done
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status|auto}"
        ;;
esac
