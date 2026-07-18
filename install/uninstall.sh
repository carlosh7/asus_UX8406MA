#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Uninstallation Script
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
BIN_DIR="/usr/local/bin"

echo "=============================================="
echo "  Zenbook Duo Linux - Uninstallation Script"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo:"
    echo "  sudo ./install/uninstall.sh"
    exit 1
fi

# Detect user
if [ -n "${SUDO_USER:-}" ]; then
    REMOVE_USER="$SUDO_USER"
else
    REMOVE_USER=$(logname 2>/dev/null || echo "")
fi

USER_HOME=$(getent passwd "$REMOVE_USER" 2>/dev/null | cut -d: -f6 || echo "")

echo "This will remove Zenbook Duo Linux from your system."
echo ""
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "[1/5] Stopping and disabling services..."

SERVICES="zenbook-duo.service brightness-sync.service zenbook-auto-display.service zenbook-light-monitor.service"
for svc in $SERVICES; do
    systemctl stop "$svc" 2>/dev/null && echo "  Stopped: $svc" || true
    systemctl disable "$svc" 2>/dev/null && echo "  Disabled: $svc" || true
done

echo ""
echo "[2/5] Removing installed files..."

# Remove binaries
for script in duo bk.py fn-lock.py wayland-display-mgr.py auto-display.sh light-monitor.sh start.sh toggle-bluetooth.sh kb-light-cycle.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-mgr.sh test_hardware.sh zenbook-duo; do
    rm -f "$BIN_DIR/$script" 2>/dev/null && echo "  Removed: $BIN_DIR/$script" || true
done

# Remove systemd services
rm -f /etc/systemd/system/zenbook-duo.service
rm -f /etc/systemd/system/brightness-sync.service
rm -f /etc/systemd/system/zenbook-auto-display.service
rm -f /etc/systemd/system/zenbook-light-monitor.service
rm -f /etc/systemd/system/mic-boost.service
systemctl daemon-reload
echo "  Systemd services removed"

echo ""
echo "[3/5] Removing configuration..."

# Remove config directory
rm -rf /etc/zenbook-duo/
echo "  Removed /etc/zenbook-duo/"

# Remove modprobe configs
rm -f /etc/modprobe.d/zenbook-duo-audio.conf
rm -f /etc/modprobe.d/iwlwifi-zenbook.conf
echo "  Removed kernel module options"

# Remove sudoers
rm -f /etc/sudoers.d/zenbook-duo
echo "  Removed sudoers entry"

echo ""
echo "[4/5] Removing user files..."

if [ -n "$USER_HOME" ]; then
    # Remove autostart
    rm -f "$USER_HOME/.config/autostart/zenbook-duo.desktop" 2>/dev/null || true
    
    # Ask about EasyEffects profile
    read -p "  Remove EasyEffects profile? (y/N): " remove_ee
    if [[ "$remove_ee" =~ ^[Yy]$ ]]; then
        rm -f "$USER_HOME/.config/easyeffects/output/ZenbookDuo.json" 2>/dev/null || true
        echo "  Removed EasyEffects profile"
    else
        echo "  Kept EasyEffects profile"
    fi
fi

echo ""
echo "[5/5] Cleaning up..."

# Remove daemon binary
rm -f /usr/local/bin/zenbook-duo 2>/dev/null || true

# Remove build artifacts
cd "$REPO_DIR/daemon" 2>/dev/null && make clean 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Uninstallation Complete!"
echo "=============================================="
echo ""
echo "  Please restart your session for changes to take effect."
echo ""
