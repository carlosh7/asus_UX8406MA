#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Unified Keyboard Backlight Manager
# Features: ambient light, inactivity, screen lock detection
# ============================================================================

BK_SCRIPT="/usr/local/bin/bk.py"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
STATE_FILE="/tmp/zenbook-kb-backlight.state"
LOG_FILE="/var/log/zenbook-kb-backlight.log"

# --- Configuration -----------------------------------------------------------

CHECK_INTERVAL=3          # Seconds between checks
INACTIVITY_TIMEOUT=10000  # 10 seconds idle -> turn off backlight

# Light thresholds (raw ALS values for UX8406MA with scale=0.001)
LIGHT_THRESHOLD_HIGH=2500    # >2500 raw -> level 0 (off)

# --- Functions ---------------------------------------------------------------

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

get_idle_ms() {
    local idle=$(dbus-send --print-reply --dest=org.gnome.Mutter.IdleMonitor \
        /org/gnome/Mutter/IdleMonitor/Core \
        org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null | \
        grep uint64 | awk '{print $2}')
    echo "${idle:-0}"
}

get_ambient_light() {
    if [ -n "$ALS_PATH" ] && [ -f "$ALS_PATH" ]; then
        cat "$ALS_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_light_level() {
    local lux="$1"
    if [ "$lux" -gt "$LIGHT_THRESHOLD_HIGH" ] 2>/dev/null; then
        echo "0"
    else
        echo "1"
    fi
}

set_keyboard_backlight() {
    local level="$1"
    local current_level=$(cat "$STATE_FILE" 2>/dev/null || echo "-1")
    
    if [ "$level" != "$current_level" ]; then
        sudo -n python3 "$BK_SCRIPT" "$level" 2>/dev/null
        echo "$level" > "$STATE_FILE"
        log_msg "Backlight: $current_level -> $level"
    fi
}

keyboard_is_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

# --- Main Loop ---------------------------------------------------------------

echo "2" > "$STATE_FILE"

while true; do
    if ! keyboard_is_attached; then
        set_keyboard_backlight "0"
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    lux=$(get_ambient_light)
    
    if [ -z "$lux" ] || [ "$lux" -eq 0 ] 2>/dev/null; then
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    light_level=$(get_light_level "$lux")
    idle_ms=$(get_idle_ms)
    
    if [ "$idle_ms" -ge "$INACTIVITY_TIMEOUT" ] 2>/dev/null; then
        set_keyboard_backlight "0"
    else
        set_keyboard_backlight "$light_level"
    fi
    
    sleep "$CHECK_INTERVAL"
done
