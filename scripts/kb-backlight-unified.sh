#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Unified Keyboard Backlight Manager v2
# Fixes: inactivity-first logic, state machine, 4 levels, 30s timeout
# ============================================================================

BK_SCRIPT="/usr/local/bin/bk.py"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
STATE_FILE="/tmp/zenbook-kb-backlight.state"
LOG_FILE="/var/log/zenbook-kb-backlight.log"

# --- Configuration -----------------------------------------------------------

CHECK_INTERVAL=3            # Seconds between checks
INACTIVITY_TIMEOUT=30000    # 30 seconds idle -> turn off backlight

# Light thresholds (raw ALS values, scale=0.001)
# 272 raw = 0.27 lux (dark room), 2500+ = bright room
LIGHT_BRIGHT=2500     # >2500 raw -> level 0 (off, bright enough)
LIGHT_DIM=1500        # >1500 raw -> level 1 (dim)
LIGHT_DARK=500        # >500 raw  -> level 2 (dark)
                        # <=500 raw -> level 3 (pitch black)

# --- Functions ---------------------------------------------------------------

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

# Resolve ALS path dynamically (find sensor named "als")
resolve_als_path() {
    local path=""
    for dev in /sys/bus/iio/devices/iio:device*/name; do
        if [ "$(cat "$dev" 2>/dev/null)" = "als" ]; then
            local dir=$(dirname "$dev")
            path="$dir/in_illuminance_raw"
            break
        fi
    done
    echo "$path"
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
    if [ -z "$lux" ] || [ "$lux" -eq 0 ] 2>/dev/null; then
        echo "1"   # lux=0 or empty -> dark (safe default: on)
    elif [ "$lux" -gt "$LIGHT_BRIGHT" ] 2>/dev/null; then
        echo "0"   # Bright -> off
    elif [ "$lux" -gt "$LIGHT_DIM" ] 2>/dev/null; then
        echo "1"   # Dim -> level 1
    elif [ "$lux" -gt "$LIGHT_DARK" ] 2>/dev/null; then
        echo "2"   # Dark -> level 2
    else
        echo "3"   # Pitch black -> level 3
    fi
}

set_keyboard_backlight() {
    local level="$1"
    local current_level=$(cat "$STATE_FILE" 2>/dev/null || echo "-1")

    if [ "$level" != "$current_level" ]; then
        python3 "$BK_SCRIPT" "$level" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$level" > "$STATE_FILE"
            log_msg "Backlight: $current_level -> $level"
        fi
    fi
}

keyboard_is_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

# --- Main Loop ---------------------------------------------------------------

ALS_PATH=$(resolve_als_path)
log_msg "Starting v2 | ALS: $ALS_PATH | Timeout: ${INACTIVITY_TIMEOUT}ms"
echo "2" > "$STATE_FILE"

PREV_IDLE_STATE="active"   # "active" or "idle"

while true; do
    # 1. Keyboard attached?
    if ! keyboard_is_attached; then
        set_keyboard_backlight "0"
        PREV_IDLE_STATE="active"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # 2. Check inactivity FIRST (before ALS)
    idle_ms=$(get_idle_ms)

    if [ "$idle_ms" -ge "$INACTIVITY_TIMEOUT" ] 2>/dev/null; then
        # IDLE: turn off backlight
        if [ "$PREV_IDLE_STATE" != "idle" ]; then
            log_msg "Idle detected (${idle_ms}ms) -> OFF"
            PREV_IDLE_STATE="idle"
        fi
        set_keyboard_backlight "0"
    else
        # ACTIVE: restore backlight based on ambient light
        if [ "$PREV_IDLE_STATE" = "idle" ]; then
            log_msg "Activity detected (${idle_ms}ms) -> restoring"
            PREV_IDLE_STATE="active"
        fi

        lux=$(get_ambient_light)
        light_level=$(get_light_level "$lux")
        set_keyboard_backlight "$light_level"
    fi

    sleep "$CHECK_INTERVAL"
done
