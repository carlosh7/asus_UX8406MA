#!/bin/bash
# Monitor keyboard inactivity - turn off backlight after 30s idle

BK_SCRIPT="/usr/local/bin/bk.py"
IDLE_TIMEOUT=30
CHECK_INTERVAL=2

last_activity=$(date +%s)
backlight_on=false
was_dark=false

while true; do
    idle=$(sudo cat /sys/class/input/*/idle 2>/dev/null | head -1)
    
    current_time=$(date +%s)
    
    if xdotool getactivewindow getwindowname >/dev/null 2>&1; then
        last_activity=$current_time
    fi
    
    time_since_activity=$((current_time - last_activity))
    
    lux=$(cat /sys/bus/iio/devices/iio:device0/in_illuminance_raw 2>/dev/null)
    is_dark=false
    if [ -n "$lux" ] && [ "$lux" -lt 2000 ]; then
        is_dark=true
    fi
    
    if [ "$is_dark" = true ] && [ "$was_dark" = false ]; then
        if [ "$time_since_activity" -lt "$IDLE_TIMEOUT" ]; then
            sudo -n python3 "$BK_SCRIPT" 3 2>/dev/null
            backlight_on=true
        fi
    fi
    
    if [ "$is_dark" = true ] && [ "$backlight_on" = true ] && [ "$time_since_activity" -ge "$IDLE_TIMEOUT" ]; then
        sudo -n python3 "$BK_SCRIPT" 0 2>/dev/null
        backlight_on=false
    fi
    
    if [ "$is_dark" = false ]; then
        backlight_on=false
    fi
    
    was_dark=$is_dark
    
    sleep "$CHECK_INTERVAL"
done