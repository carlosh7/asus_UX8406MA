#!/bin/bash
# ============================================================================
# Zenbook Duo - Suspend/Resume Keyboard Backlight Hook
# Turns on keyboard backlight after resume from suspend
# ============================================================================

BK_SCRIPT="/usr/local/bin/bk.py"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)

# Get ambient light level
get_light_level() {
    if [ -n "$ALS_PATH" ] && [ -f "$ALS_PATH" ]; then
        lux=$(cat "$ALS_PATH" 2>/dev/null || echo "0")
        if [ "$lux" -gt 15000 ] 2>/dev/null; then
            echo "1"
        elif [ "$lux" -gt 5000 ] 2>/dev/null; then
            echo "2"
        else
            echo "3"
        fi
    else
        echo "2"
    fi
}

# Check if keyboard is attached
keyboard_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

case "$1" in
    post)
        # After resume - turn on keyboard backlight
        sleep 1  # Wait for USB devices to initialize
        if keyboard_attached; then
            level=$(get_light_level)
            sudo -n python3 "$BK_SCRIPT" "$level" 2>/dev/null
            echo "$level" > /tmp/zenbook-kb-backlight.state
            echo "[$(date '+%H:%M:%S')] Resume: backlight set to $level" >> /var/log/zenbook-kb-backlight.log
        fi
        ;;
    pre)
        # Before suspend - turn off keyboard backlight
        sudo -n python3 "$BK_SCRIPT" 0 2>/dev/null
        echo "0" > /tmp/zenbook-kb-backlight.state
        echo "[$(date '+%H:%M:%S')] Suspend: backlight off" >> /var/log/zenbook-kb-backlight.log
        ;;
esac
