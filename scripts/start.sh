#!/bin/bash
# Zenbook Duo Linux - Start scripts on login

BIN_DIR="/usr/local/bin"

# Setup display positions on login
"$BIN_DIR/setup-displays.sh"

# Start auto-display (LEGACY - now handled by zenbook-duo daemon)
# nohup "$BIN_DIR/auto-display.sh" > /tmp/zenbook-auto.log 2>&1 &

# Start light monitor (adjust keyboard backlight based on ambient light)
nohup "$BIN_DIR/light-monitor.sh" > /tmp/zenbook-light.log 2>&1 &

echo "Zenbook Duo scripts started"
echo "  - auto-display: toggle screen when keyboard attached/detached"
echo "  - light-monitor: adjust keyboard backlight based on ambient light"