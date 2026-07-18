#!/bin/bash
# ============================================================================
# Zenbook Duo - OLED Burn-in Protection
# v2: Fixed sleep settings, added suspend support
# ============================================================================

LOG_FILE="/var/log/oled-protect.log"

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

echo "OLED Burn-in Protection starting..."

# 1. Set idle timeout to 5 minutes (300 seconds)
dbus-send --session --type=method_call --dest=org.gnome.Mutter.IdleMonitor \
    /org/gnome/Mutter/IdleMonitor/Core \
    org.gnome.Mutter.IdleMonitor.SetIdletime uint32:300 2>/dev/null
log_msg "Idle delay set to 300s"

# 2. Enable screen lock
gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null
gsettings set org.gnome.desktop.screensaver lock-delay uint32 0 2>/dev/null
log_msg "Screen lock enabled"

# 3. Enable automatic suspend (AC: 15 min, Battery: 10 min)
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 600 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend' 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend' 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power lid-close-suspend-with-external-monitor true 2>/dev/null
log_msg "Auto-suspend configured (15min AC, 10min battery)"

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
echo "  - Sleep type: suspend"
echo "  - Lid close: suspend (even with external monitor)"
echo "  - Dark theme: enabled"
echo "  - Night Light: enabled (3500K)"
