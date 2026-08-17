#!/bin/bash
# Zenbook Duo - Initial display setup on login
# Uses duo (session-aware: DBus on Wayland, xrandr on X11)

sleep 2

# Check if keyboard is attached via USB
if lsusb 2>/dev/null | grep -q "0b05:1b2c"; then
    # Keyboard ATTACHED: only top display (eDP-1)
    duo top 2>/dev/null
    echo "Keyboard attached: top display"
else
    # Keyboard DETACHED: both displays on
    duo both 2>/dev/null
    echo "Keyboard detached: both displays"
fi
