#!/bin/bash

# Keyboard backlight auto-manager with ambient light sensor
# Automatically adjusts keyboard backlight based on ambient light

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BK_SCRIPT="$SCRIPT_DIR/bk.py"
STATE_FILE="/tmp/zenbook-kb-backlight.state"
ALS_PATH="/sys/bus/iio/devices/iio:device0"

# Light thresholds (inverted: higher = darker)
# Values around 800+ = very dark room, <100 = bright
LIGHT_HIGH=300     # Bright - backlight off
LIGHT_MED=150     # Medium - level 1
LIGHT_LOW=50       # Dark - level 2
LIGHT_VERY_LOW=10 # Very dark - level 3

get_ambient_light() {
    if [ -f "$ALS_PATH/in_illuminance_raw" ]; then
        cat "$ALS_PATH/in_illuminance_raw" 2>/dev/null
    else
        echo "0"
    fi
}

get_light_level() {
    local lux=$(get_ambient_light)
    
    # Inverted: higher values = darker (covered), lower = brighter (exposed)
    if [ "$lux" -lt "$LIGHT_LOW" ]; then
        echo "0"  # Very bright - off
    elif [ "$lux" -lt "$LIGHT_MED" ]; then
        echo "1"  # Medium - level 1
    elif [ "$lux" -lt "$LIGHT_HIGH" ]; then
        echo "2"  # Dark - level 2
    else
        echo "3"  # Very dark (covered) - level 3
    fi
}

set_kb_light() {
    local level="$1"
    if [ -z "$level" ]; then
        return
    fi
    sudo python3 "$BK_SCRIPT" "$level" 2>/dev/null
    echo "$level" > "$STATE_FILE"
    echo "Keyboard backlight set to level $level (ambient: $(get_ambient_light))"
}

check_keyboard() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

init_state() {
    if [ -f "$STATE_FILE" ]; then
        LAST_LEVEL=$(cat "$STATE_FILE")
    else
        LAST_LEVEL=2
        echo "$LAST_LEVEL" > "$STATE_FILE"
    fi
}

monitor() {
    echo "=== Keyboard Backlight Auto-Manager ==="
    echo "Monitoring keyboard & ambient light..."
    echo "Light sensor: $ALS_PATH"
    echo ""
    
    init_state
    LAST_LEVEL=$(cat "$STATE_FILE")
    was_connected=false
    
    while true; do
        is_connected=$(check_keyboard)
        current_light=$(get_light_level)
        
        if [ "$is_connected" = true ]; then
            if [ "$was_connected" = false ]; then
                # Keyboard just connected - set based on ambient light
                echo "[$(date '+%H:%M:%S')] Keyboard connected"
                set_kb_light "$current_light"
                was_connected=true
            else
                # Already connected - check if light changed significantly
                saved_level=$(cat "$STATE_FILE" 2>/dev/null)
                if [ "$current_light" != "$saved_level" ]; then
                    set_kb_light "$current_light"
                fi
            fi
        else
            was_connected=false
        fi
        
        sleep 3
    done
}

case "$1" in
    start)
        monitor
        ;;
    light)
        get_ambient_light
        ;;
    level)
        get_light_level
        ;;
    set)
        set_kb_light "$2"
        ;;
    get)
        init_state
        echo "Current: $(cat $STATE_FILE), Ambient: $(get_ambient_light)"
        ;;
    *)
        echo "Usage: $0 <start|light|level|set <0-3>|get>"
        echo ""
        echo "Ambient light values:"
        echo "  > 100 : Bright (off)"
        echo "  30-100: Medium (level 1)"
        echo "  10-30 : Dark (level 2)"
        echo "  < 10  : Very dark (level 3)"
        ;;
esac