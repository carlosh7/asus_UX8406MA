#!/bin/bash

check_keyboard() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

echo "=== Auto Display ==="

# IMMEDIATELY set correct state based on current keyboard state
if check_keyboard; then
    # Keyboard IS attached - only top display
    duo top 2>/dev/null
    echo "Initial: keyboard attached - top display"
else
    # Keyboard NOT attached - both screens on
    duo both 2>/dev/null
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
            duo top 2>/dev/null
            echo "[PUESTO] top display"
        else
            duo both 2>/dev/null
            echo "[QUITADO] both displays"
        fi
        last=$now
    fi
    
    sleep 1
done
