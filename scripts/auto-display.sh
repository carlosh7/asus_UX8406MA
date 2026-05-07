#!/bin/bash

check_keyboard() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

echo "=== Auto Display ==="

# IMMEDIATELY set correct state based on current keyboard state
if check_keyboard; then
    # Keyboard IS attached - turn off bottom screen NOW
    xrandr --output eDP-2 --off 2>/dev/null
    echo "Initial: keyboard attached - eDP-2 OFF"
else
    # Keyboard NOT attached - both screens on
    xrandr --output eDP-1 --auto --primary 2>/dev/null
    xrandr --output eDP-2 --mode 2880x1800 --below eDP-1 2>/dev/null
    echo "Initial: keyboard detached - both ON"
fi

last="unknown"

while true; do
    if check_keyboard; then
        now="attached"
    else
        now="detached"
    fi
    
    if [ "$now" != "$last" ]; then
        if [ "$now" = "attached" ]; then
            xrandr --output eDP-2 --off 2>/dev/null
            echo "[PUESTO] eDP-2 OFF"
        else
            xrandr --output eDP-2 --mode 2880x1800 --below eDP-1 2>/dev/null
            echo "[QUITADO] eDP-2 ON"
        fi
        last=$now
    fi
    
    sleep 1
done