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

# OS Detection
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "[1/6] Installing dependencies for $OS..."

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        apt-get update -qq
        apt-get install -y -qq \
            python3 \
            python3-usb \
            inotify-tools \
            lm-sensors \
            iio-sensor-proxy \
            easyeffects \
            lsp-plugins \
            usbutils \
            build-essential \
            gcc \
            make \
            pkg-config \
            libusb-1.0-0-dev \
            libglib2.0-dev 2>/dev/null || true
        ;;
    arch|manjaro|endeavouros)
        pacman -Sy --noconfirm \
            python \
            python-pyusb \
            inotify-tools \
            lm_sensors \
            iio-sensor-proxy \
            easyeffects \
            lsp-plugins \
            usbutils \
            base-devel \
            libusb \
            glib2 2>/dev/null || true
        ;;
    *)
        echo "Unsupported OS: $OS. Please install dependencies manually."
        ;;
esac

echo ""
echo "[2/6] Compiling and installing the daemon..."
cd "$REPO_DIR/daemon"
make clean
make
make install
cd "$REPO_DIR"

echo ""
echo "[3/6] Installing CLI scripts..."
cp -r "$REPO_DIR/scripts/"* "$BIN_DIR/"
chmod +x "$BIN_DIR/duo" "$BIN_DIR/bk.py" "$BIN_DIR/fn-lock.py"
chmod +x "$BIN_DIR/auto-display.sh" "$BIN_DIR/light-monitor.sh" "$BIN_DIR/start.sh"
chmod +x "$BIN_DIR/toggle-bluetooth.sh" "$BIN_DIR/kb-light-cycle.sh" "$BIN_DIR/setup-hotkeys.sh"

echo ""
echo "[4/6] Configuring Audio Optimizations..."
# Copy EasyEffects profile for current user and root
mkdir -p "$HOME/.config/easyeffects/output/"
cp "$REPO_DIR/config/easyeffects/output/ZenbookDuo.json" "$HOME/.config/easyeffects/output/" 2>/dev/null || true
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    mkdir -p "$USER_HOME/.config/easyeffects/output/"
    cp "$REPO_DIR/config/easyeffects/output/ZenbookDuo.json" "$USER_HOME/.config/easyeffects/output/"
    chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/easyeffects/"
fi

# Set kernel options for speakers
echo "options snd-hda-intel model=asus-zenbook" > /etc/modprobe.d/zenbook-duo-audio.conf
echo "options snd-sof-intel-hda-common hda_model=asus-zenbook" >> /etc/modprobe.d/zenbook-duo-audio.conf

echo ""
echo "[5/6] Setting up sudoers and systemd services..."
echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zenbook-duo
chmod 0440 /etc/sudoers.d/zenbook-duo

# Install systemd services
cp "$REPO_DIR/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload

# Enable and start services
systemctl enable zenbook-duo.service 2>/dev/null || true
systemctl enable brightness-sync.service 2>/dev/null || true
systemctl enable zenbook-auto-display.service 2>/dev/null || true
systemctl start zenbook-duo.service 2>/dev/null || true

# Create GNOME autostart if it doesn't exist (for UI tools)
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    AUTOSTART_DIR="$USER_HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/zenbook-duo.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Zenbook Duo
Exec=$BIN_DIR/start.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    chown "$SUDO_USER:$SUDO_USER" "$AUTOSTART_DIR/zenbook-duo.desktop"
fi

echo ""
echo "[6/6] Finalizing hardware settings..."
echo 80 | tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null 2>&1 || true
amixer -c 0 sset Master 100% 2>/dev/null || true
amixer -c 0 sset Speaker 100% 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "To finish setup:"
echo "  1. Restart your session (Log out and back in)"
echo "  2. Run 'duo help' to see available commands"
echo "  3. Open EasyEffects and select the 'ZenbookDuo' profile"
echo ""