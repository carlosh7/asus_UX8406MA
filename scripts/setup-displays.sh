#!/bin/bash
# Setup display positions on login

sleep 2

if lsusb 2>/dev/null | grep -q "0b05:1b2c"; then
    xrandr --output eDP-2 --off 2>/dev/null
else
    xrandr --output eDP-2 --off 2>/dev/null
    xrandr --output eDP-1 --mode 2880x1800 --pos 0x0 --primary 2>/dev/null
    xrandr --output eDP-2 --mode 2880x1800 --pos 0x1800 2>/dev/null
fi