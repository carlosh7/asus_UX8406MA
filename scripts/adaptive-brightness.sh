#!/bin/bash
# ============================================================================
# Zenbook Duo - Adaptive Brightness Controller
# Custom brightness adaptation based on ALS sensor calibration
# Supports: manual pause, auto-resume on light change
# ============================================================================

ALS_PATH="/sys/bus/iio/devices/iio:device1/in_illuminance_raw"
BRIGHTNESS_PATH="/sys/class/backlight/intel_backlight/brightness"
MAX_BRIGHTNESS="/sys/class/backlight/intel_backlight/max_brightness"
STATE_FILE="/tmp/zenbook-adaptive-brightness.state"
LOG_FILE="/var/log/zenbook-adaptive-brightness.log"
CHECK_INTERVAL=5

# Calibration points (ALS raw -> brightness %)
CALIBRATION=(
    "272:6"        # Oscuro: 0.3 lux -> 6%
    "109545:39"    # Artificial: 109 lux -> 39%
    "122822:62"    # Escritorio: 122 lux -> 62%
    "540319:100"   # Ventana: 540 lux -> 100%
)

# State tracking
LAST_ALS=0
LAST_BRIGHTNESS=0
PAUSED=0
PAUSE_THRESHOLD=20000

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

get_ambient_light() {
    if [ -f "$ALS_PATH" ]; then
        cat "$ALS_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_max_brightness() {
    cat "$MAX_BRIGHTNESS" 2>/dev/null || echo "400"
}

get_current_brightness() {
    cat "$BRIGHTNESS_PATH" 2>/dev/null || echo "0"
}

interpolate_brightness() {
    local als="$1"
    local max_br=$(get_max_brightness)
    
    local prev_als=0
    local prev_br=0
    local next_als=0
    local next_br=0
    
    for cal in "${CALIBRATION[@]}"; do
        local cal_als="${cal%%:*}"
        local cal_br="${cal##*:}"
        
        if [ "$als" -ge "$cal_als" ] 2>/dev/null; then
            prev_als=$cal_als
            prev_br=$cal_br
        elif [ "$next_als" -eq 0 ]; then
            next_als=$cal_als
            next_br=$cal_br
        fi
    done
    
    if [ "$next_als" -gt 0 ] && [ "$prev_als" -gt 0 ]; then
        local range=$((next_als - prev_als))
        local pos=$((als - prev_als))
        local br_range=$((next_br - prev_br))
        
        if [ "$range" -gt 0 ]; then
            local br=$((prev_br + (pos * br_range / range)))
            echo $((br * max_br / 100))
        else
            echo $((prev_br * max_br / 100))
        fi
    elif [ "$prev_als" -gt 0 ]; then
        echo $((prev_br * max_br / 100))
    else
        echo $((next_br * max_br / 100))
    fi
}

set_brightness() {
    local target="$1"
    local current=$(get_current_brightness)
    local max=$(get_max_brightness)
    
    if [ "$target" -lt 1 ] 2>/dev/null; then
        target=1
    elif [ "$target" -gt "$max" ] 2>/dev/null; then
        target=$max
    fi
    
    local diff=$((target - current))
    if [ "$diff" -gt 5 ] || [ "$diff" -lt -5 ] 2>/dev/null; then
        echo "$target" > "$BRIGHTNESS_PATH"
        log_msg "Brightness: $current -> $target (ALS: $(get_ambient_light))"
    fi
}

# Initialize
LAST_BRIGHTNESS=$(get_current_brightness)
LAST_ALS=$(get_ambient_light)

# Main loop
log_msg "Adaptive brightness started (initial: ALS=$LAST_ALS, BR=$LAST_BRIGHTNESS)"
echo "Adaptive brightness controller started"

while true; do
    als=$(get_ambient_light)
    current_br=$(get_current_brightness)
    
    if [ -z "$als" ] || [ "$als" -eq 0 ] 2>/dev/null; then
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # STEP 1: Detect manual change
    # If brightness changed AND ALS didn't change significantly -> user changed it
    als_diff=$((als - LAST_ALS))
    if [ "$als_diff" -lt 0 ]; then als_diff=$((als_diff * -1)); fi
    
    if [ "$current_br" -ne "$LAST_BRIGHTNESS" ] 2>/dev/null && [ "$als_diff" -lt "$PAUSE_THRESHOLD" ] 2>/dev/null; then
        # User changed brightness manually, ALS stable
        if [ "$PAUSED" -eq 0 ]; then
            log_msg "PAUSED (manual: $LAST_BRIGHTNESS -> $current_br, ALS stable)"
            PAUSED=1
        fi
        LAST_ALS=$als
        LAST_BRIGHTNESS=$current_br
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # STEP 2: If paused, check if ALS changed significantly -> resume
    if [ "$PAUSED" -eq 1 ]; then
        if [ "$als_diff" -ge "$PAUSE_THRESHOLD" ] 2>/dev/null; then
            log_msg "RESUMED (ALS: $LAST_ALS -> $als)"
            PAUSED=0
        else
            # Still paused, don't change brightness
            LAST_ALS=$als
            LAST_BRIGHTNESS=$current_br
            sleep "$CHECK_INTERVAL"
            continue
        fi
    fi
    
    # STEP 3: Auto-adjust
    target=$(interpolate_brightness "$als")
    set_brightness "$target"
    
    LAST_ALS=$als
    LAST_BRIGHTNESS=$(get_current_brightness)
    
    sleep "$CHECK_INTERVAL"
done
