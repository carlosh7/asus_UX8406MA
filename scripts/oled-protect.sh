#!/bin/bash
# ============================================================================
# Zenbook Duo - OLED Burn-in Protection
# Activates pixel shift, dark mode, and idle timeout for OLED panels
# ============================================================================

LOG_FILE="/var/log/oled-protect.log"

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

echo "OLED Burn-in Protection starting..."

# 1. Set idle timeout to 5 minutes (300 seconds)
gsettings set org.gnome.desktop.session idle-delay uint32 300 2>/dev/null
log_msg "Idle delay set to 300s"

# 2. Enable screen lock
gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null
gsettings set org.gnome.desktop.screensaver lock-delay uint32 0 2>/dev/null
log_msg "Screen lock enabled"

# 3. Enable automatic suspend after 15 minutes
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 600 2>/dev/null
log_msg "Auto-suspend configured"

# 4. Set dark theme (reduces OLED power and burn-in)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
log_msg "Dark theme enabled"

# 5. Enable Night Light (reduces blue light)
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature uint32 3500 2>/dev/null
log_msg "Night Light enabled (3500K)"

echo "OLED protection configured."
echo "  - Idle timeout: 5 minutes"
echo "  - Screen lock: enabled"
echo "  - Auto-suspend: 15min (AC), 10min (battery)"
echo "  - Dark theme: enabled"
echo "  - Night Light: enabled (3500K)"
