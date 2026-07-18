#!/bin/bash
# Zenbook Duo - Touch Mapping Setup for Wayland
# Uses dconf with correct device IDs

echo "Setting up touch mapping for Wayland..."

# Tablet mapping
dconf write "/org/gnome/desktop/peripherals/tablets/04f3:425b/output" "['SDC', '0x419d', '0x00000000', 'eDP-1']" 2>/dev/null
dconf write "/org/gnome/desktop/peripherals/tablets/04f3:425a/output" "['SDC', '0x419d', '0x00000000', 'eDP-2']" 2>/dev/null

# Touchscreen mapping
dconf write "/org/gnome/desktop/peripherals/touchscreens/04f3:425b/output" "['SDC', '0x419d', '0x00000000', 'eDP-1']" 2>/dev/null
dconf write "/org/gnome/desktop/peripherals/touchscreens/04f3:425a/output" "['SDC', '0x419d', '0x00000000', 'eDP-2']" 2>/dev/null

echo "Touch mapping configured"
echo "  425b (bottom touch) -> eDP-1"
echo "  425a (top touch) -> eDP-2"
