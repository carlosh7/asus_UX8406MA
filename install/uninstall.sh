#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Uninstallation Script
# Removes all installed components: services, scripts, udev, TLP, sysctl, NPU
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

ALL_SERVICES="zenbook-duo.service brightness-sync.service zenbook-auto-display.service zenbook-light-monitor.service zenbook-thermal.service zenbook-adaptive-brightness.service zenbook-config.service battery-limit.service zenbook-nightlight.service zenbook-suspend-backlight.service mic-boost.service zenbook-bt-keyboard.service"
for svc in $ALL_SERVICES; do
    systemctl stop "$svc" 2>/dev/null && echo "  Stopped: $svc" || true
    systemctl disable "$svc" 2>/dev/null && echo "  Disabled: $svc" || true
done

# TLP service (enabled by installer)
if [ -f /etc/tlp.d/01-zenbook.conf ]; then
    systemctl stop tlp 2>/dev/null || true
    systemctl disable tlp 2>/dev/null || true
    echo "  TLP stopped and disabled"
fi

# Powertop auto-tune (created by installer)
if [ -f /etc/systemd/system/powertop.service ]; then
    systemctl stop powertop 2>/dev/null || true
    systemctl disable powertop 2>/dev/null || true
    rm -f /etc/systemd/system/powertop.service
    echo "  Powertop service removed"
fi

echo ""
echo "[2/5] Removing installed files..."

# Remove binaries (all installed by install.sh)
for script in duo bk.py fn-lock.py wayland-display-mgr.py auto-display.sh light-monitor.sh start.sh toggle-bluetooth.sh kb-light-cycle.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-mgr.sh kb-backlight-unified.sh adaptive-brightness.sh thermal-monitor.sh audio-diagnose.sh audio-calibrate.sh wifi-diagnose.sh test_hardware.sh webcam-diagnose.sh webcam-optimize.sh bt-keyboard-mapper.py zenbook-config.sh suspend-backlight.sh nightlight.sh ssd-health.sh fn-lock.sh system-health.sh disk-monitor.sh weekly-maintenance.sh zzz-keyboard-light oled-protect.sh webcam-privacy.sh firmware-check.sh zenbook-health-check.sh zenbook-boot-test.sh touch-remap.sh setup-touch-wayland.sh zenbook-duo amp-enable.sh; do
    rm -f "$BIN_DIR/$script" 2>/dev/null || true
done
echo "  CLI scripts removed from $BIN_DIR"

# Remove systemd services
for svc in $ALL_SERVICES; do
    rm -f "/etc/systemd/system/$svc" 2>/dev/null || true
done
systemctl daemon-reload
echo "  Systemd services removed"

echo ""
echo "[3/5] Removing configuration..."

# Remove config directory
rm -rf /etc/zenbook-duo/
echo "  Removed /etc/zenbook-duo/"

# Remove udev rules
rm -f /etc/udev/rules.d/50-usb-power-management.rules
rm -f /etc/udev/rules.d/99-zenbook-keyboard.rules
rm -f /etc/udev/rules.d/99-zenbook-npu.rules
rm -f /etc/udev/rules.d/99-zenbook-duo-amp.rules
udevadm control --reload-rules 2>/dev/null || true
echo "  Udev rules removed"

# Remove modprobe configs
rm -f /etc/modprobe.d/zenbook-duo-audio.conf
rm -f /etc/modprobe.d/iwlwifi-zenbook.conf
rm -f /etc/modprobe.d/xe-gpu-optimize.conf
echo "  Kernel module options removed"

# Remove sysctl tuning
rm -f /etc/sysctl.d/99-performance.conf
echo "  Sysctl tuning removed"

# Remove logrotate config
rm -f /etc/logrotate.d/zenbook-duo.conf
echo "  Logrotate config removed"

# Remove sudoers
rm -f /etc/sudoers.d/zenbook-duo
echo "  Removed sudoers entry"

# Remove TLP config
rm -f /etc/tlp.d/01-zenbook.conf
echo "  TLP config removed"

# Remove state and logs
rm -rf /var/lib/zenbook-duo
rm -f /var/log/zenbook-*.log
rm -f /var/log/boot-test.log /var/log/weekly-maintenance.log /var/log/disk-monitor.log
echo "  State directory and logs removed"

echo ""
echo "[4/5] Removing user files..."

if [ -n "$USER_HOME" ]; then
    # Remove autostart
    rm -f "$USER_HOME/.config/autostart/zenbook-duo.desktop" 2>/dev/null || true
    
    # Remove user systemd services
    rm -f "$USER_HOME/.config/systemd/user/zenbook-bt-keyboard.service" 2>/dev/null || true
    
    # Ask about EasyEffects profile
    read -p "  Remove EasyEffects profile? (y/N): " remove_ee
    if [[ "$remove_ee" =~ ^[Yy]$ ]]; then
        rm -f "$USER_HOME/.config/easyeffects/output/ZenbookDuo.json" 2>/dev/null || true
        rm -f "$USER_HOME/.config/easyeffects/output/ZenbookDuo-Spatial.json" 2>/dev/null || true
        echo "  Removed EasyEffects profile"
    else
        echo "  Kept EasyEffects profile"
    fi

    # Ask about dconf touch mapping
    read -p "  Remove dconf touch mapping? (y/N): " remove_dconf
    if [[ "$remove_dconf" =~ ^[Yy]$ ]]; then
        sudo -u "$REMOVE_USER" gsettings reset org.gnome.desktop.peripherals.touchscreens 04f3:425b 2>/dev/null || true
        sudo -u "$REMOVE_USER" gsettings reset org.gnome.desktop.peripherals.touchscreens 04f3:425a 2>/dev/null || true
        echo "  Touch mapping reset"
    else
        echo "  Kept touch mapping"
    fi
fi

echo ""
echo "[5/5] Cleaning up..."

# Remove NPU driver (installed by installer)
dpkg -r intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu libze1 2>/dev/null || true
echo "  NPU driver removed (if installed)"

# Remove Python AI packages
pip3 uninstall -y openvino onnxruntime-openvino 2>/dev/null || true

# Remove daemon build artifacts
cd "$REPO_DIR/daemon" 2>/dev/null && make clean 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Uninstallation Complete!"
echo "=============================================="
echo ""
echo "  Please restart your session for changes to take effect."
echo ""