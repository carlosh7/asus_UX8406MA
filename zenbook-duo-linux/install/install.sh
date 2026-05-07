#!/bin/bash

REPO_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
BIN_DIR="/usr/local/bin"

echo "=============================================="
echo "  Zenbook Duo Linux - Installation Script"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo:"
    echo "  sudo ./install.sh"
    exit 1
fi

echo "[1/6] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq \
    python3 \
    python3-usb \
    inotify-tools \
    lm-sensors \
    iio-sensor-proxy \
    usbutils \
    build-essential 2>/dev/null || true

echo ""
echo "[2/6] Installing scripts..."
cp -r "$REPO_DIR/scripts/"* "$BIN_DIR/"
chmod +x "$BIN_DIR/duo" "$BIN_DIR/bk.py" "$BIN_DIR/fn-lock.py"
chmod +x "$BIN_DIR/auto-display.sh" "$BIN_DIR/light-monitor.sh" "$BIN_DIR/start.sh"
chmod +x "$BIN_DIR/toggle-bluetooth.sh" "$BIN_DIR/kb-light-cycle.sh" "$BIN_DIR/setup-hotkeys.sh"

echo ""
echo "[3/6] Setting up sudoers (for keyboard backlight without password)..."
echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zenbook-duo
chmod 0440 /etc/sudoers.d/zenbook-duo

echo ""
echo "[4/6] Configuring auto-start on login..."
# Add to bashrc
if ! grep -q "zenbook-duo-linux/start.sh" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Zenbook Duo auto-start" >> ~/.bashrc
    echo "$BIN_DIR/start.sh" >> ~/.bashrc
fi

# Create GNOME autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/zenbook-duo.desktop << EOF
[Desktop Entry]
Type=Application
Name=Zenbook Duo
Exec=$BIN_DIR/start.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "[5/6] Enabling battery limit..."
echo 80 | tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null 2>&1 || true

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "Auto-start on login:"
echo "  - auto-display.sh: toggles screen when keyboard attached/detached"
echo "  - light-monitor.sh: adjusts keyboard backlight based on ambient light"
echo ""
echo "To start now without logout:"
echo "  $BIN_DIR/start.sh"
echo ""
echo "IMPORTANT: Log out and back in for autostart to take effect."