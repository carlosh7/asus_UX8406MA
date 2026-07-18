#!/bin/bash
# Zenbook Duo - Initial display setup on login
# v2: Fixed logic, handles both X11 and Wayland gracefully

sleep 2

# Check if keyboard is attached via USB
if lsusb 2>/dev/null | grep -q "0b05:1b2c"; then
    # Keyboard ATTACHED: only top display (eDP-1)
    xrandr --output eDP-2 --off 2>/dev/null
    echo "Keyboard attached: eDP-2 OFF"
else
    # Keyboard DETACHED: both displays on
    xrandr --output eDP-1 --auto --primary 2>/dev/null
    xrandr --output eDP-2 --auto --below eDP-1 2>/dev/null
    echo "Keyboard detached: both displays ON"
fi
