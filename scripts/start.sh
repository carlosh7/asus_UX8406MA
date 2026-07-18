#!/bin/bash
# Zenbook Duo Linux - Start scripts on login
# v2: Removed duplicate light-monitor (handled by systemd service)

BIN_DIR="/usr/local/bin"

# Setup display positions on login
"$BIN_DIR/setup-displays.sh"

echo "Zenbook Duo started"
echo "  - auto-display: handled by zenbook-duo.service"
echo "  - keyboard backlight: handled by zenbook-light-monitor.service"
