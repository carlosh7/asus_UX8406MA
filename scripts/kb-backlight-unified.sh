#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Unified Keyboard Backlight Manager v3
# v3: Level 1 fixed when active + debounce (10s minimum between changes)
# ============================================================================

BK_SCRIPT="/usr/local/bin/bk.py"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
STATE_FILE="/tmp/zenbook-kb-backlight.state"
TIMESTAMP_FILE="/tmp/zenbook-kb-backlight.timestamp"
LOG_FILE="/var/log/zenbook-kb-backlight.log"

# --- Configuration -----------------------------------------------------------

CHECK_INTERVAL=3            # Seconds between checks
INACTIVITY_TIMEOUT=30000    # 30 seconds idle -> turn off backlight
DEBOUNCE_SEC=10             # Minimum seconds between level changes

# Light thresholds (raw ALS values, scale=0.001)
LIGHT_BRIGHT=2500     # >2500 raw -> level 0 (off, bright enough)

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
    if [ "$lux" -gt "$LIGHT_BRIGHT" ] 2>/dev/null; then
        echo "0"   # Bright -> off
    else
        echo "1"   # Any dark condition -> level 1 (fixed, no fluctuation)
    fi
}

# Debounce: only change if enough time passed since last change
debounce_ok() {
    local now=$(date +%s)
    local last_change=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "0")
    local elapsed=$((now - last_change))
    [ "$elapsed" -ge "$DEBOUNCE_SEC" ]
}

set_keyboard_backlight() {
    local level="$1"
    local current_level=$(cat "$STATE_FILE" 2>/dev/null || echo "-1")

    if [ "$level" != "$current_level" ]; then
        # Debounce: skip if last change was < DEBOUNCE_SEC ago
        # Exception: allow turning OFF (level 0) immediately
        if [ "$level" != "0" ] && ! debounce_ok; then
            return 0
        fi

        python3 "$BK_SCRIPT" "$level" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$level" > "$STATE_FILE"
            date +%s > "$TIMESTAMP_FILE"
            log_msg "Backlight: $current_level -> $level"
        fi
    fi
}

keyboard_is_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

# --- Main Loop ---------------------------------------------------------------

ALS_PATH=$(resolve_als_path)
log_msg "Starting v3 | ALS: $ALS_PATH | Timeout: ${INACTIVITY_TIMEOUT}ms | Debounce: ${DEBOUNCE_SEC}s"
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
        # ACTIVE: restore backlight (level 1 if dark, level 0 if bright)
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
