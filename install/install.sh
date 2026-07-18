#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Installation Script
# Supports: Ubuntu 24.04+, Debian 12+, Arch Linux
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
BIN_DIR="/usr/local/bin"
ERRORS=0

echo "=============================================="
echo "  Zenbook Duo Linux - Installation Script"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo:"
    echo "  sudo ./install/install.sh"
    exit 1
fi

# Detect logged-in user (not root)
if [ -n "${SUDO_USER:-}" ]; then
    INSTALL_USER="$SUDO_USER"
else
    INSTALL_USER=$(logname 2>/dev/null || echo "")
fi

if [ -z "$INSTALL_USER" ]; then
    echo "WARNING: Cannot detect logged-in user. Some features may not work."
fi

USER_HOME=$(getent passwd "$INSTALL_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$INSTALL_USER")

# --- OS Detection -----------------------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "[1/8] Installing dependencies for $OS..."

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        apt-get update -qq

        CRITICAL_PKGS="python3 python3-usb python3-dbus inotify-tools usbutils build-essential gcc make pkg-config libusb-1.0-0-dev libglib2.0-dev iw xdotool evtest"
        echo "  Installing critical packages..."
        if ! apt-get install -y -qq $CRITICAL_PKGS 2>/dev/null; then
            echo "ERROR: Failed to install critical dependencies."
            echo "  Try: sudo apt-get install $CRITICAL_PKGS"
            ERRORS=$((ERRORS + 1))
        fi

        OPTIONAL_PKGS="lm-sensors iio-sensor-proxy easyeffects lsp-plugins guvcview v4l2-utils"
        echo "  Installing optional packages..."
        apt-get install -y -qq $OPTIONAL_PKGS 2>/dev/null || {
            echo "  WARNING: Some optional packages failed to install."
        }
        ;;
    arch|manjaro|endeavouros)
        pacman -Sy --noconfirm

        CRITICAL_PKGS="python python-pyusb python-dbus inotify-tools usbutils base-devel libusb glib2 iw xdotool evtest"
        echo "  Installing critical packages..."
        if ! pacman -S --noconfirm $CRITICAL_PKGS 2>/dev/null; then
            echo "ERROR: Failed to install critical dependencies."
            ERRORS=$((ERRORS + 1))
        fi

        OPTIONAL_PKGS="lm_sensors iio-sensor-proxy easyeffects lsp-plugins guvcview v4l-utils"
        echo "  Installing optional packages..."
        pacman -S --noconfirm $OPTIONAL_PKGS 2>/dev/null || {
            echo "  WARNING: Some optional packages failed to install."
        }
        ;;
    *)
        echo "WARNING: Unsupported OS: $OS. Please install dependencies manually."
        ;;
esac

# Verify critical tools
echo "  Verifying installation..."
MISSING=""
for tool in python3 inotifywait iw xdotool lsusb evtest; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING="$MISSING $tool"
    fi
done
if [ -n "$MISSING" ]; then
    echo "  WARNING: Missing tools:$MISSING"
    echo "  Some features may not work correctly."
fi

# --- Compile and Install Daemon ---------------------------------------------

echo ""
echo "[2/8] Compiling and installing the daemon..."
cd "$REPO_DIR/daemon"
make clean 2>/dev/null || true
if ! make; then
    echo "ERROR: Daemon compilation failed."
    ERRORS=$((ERRORS + 1))
else
    make install
fi
cd "$REPO_DIR"

# --- Install CLI Scripts ----------------------------------------------------

echo ""
echo "[3/8] Installing CLI scripts..."

# Core scripts
CORE_SCRIPTS="duo bk.py fn-lock.py wayland-display-mgr.py"
for script in $CORE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

# Service scripts
SERVICE_SCRIPTS="auto-display.sh light-monitor.sh start.sh toggle-bluetooth.sh kb-light-cycle.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-unified.sh adaptive-brightness.sh thermal-monitor.sh audio-diagnose.sh audio-calibrate.sh wifi-diagnose.sh test_hardware.sh webcam-diagnose.sh webcam-optimize.sh bt-keyboard-mapper.py zenbook-config.sh suspend-backlight.sh nightlight.sh"
for script in $SERVICE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

echo "  Installed CLI scripts"

# --- Configure Audio --------------------------------------------------------

echo ""
echo "[4/8] Configuring audio optimizations..."

# Copy EasyEffects profile
if [ -n "$INSTALL_USER" ]; then
    mkdir -p "$USER_HOME/.config/easyeffects/output/"
    cp "$REPO_DIR/config/easyeffects/output/ZenbookDuo.json" "$USER_HOME/.config/easyeffects/output/" 2>/dev/null || true
    chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/easyeffects/" 2>/dev/null || true
    echo "  EasyEffects profile installed for $INSTALL_USER"
fi

# Kernel audio options
cat > /etc/modprobe.d/zenbook-duo-audio.conf << 'EOF'
# ASUS Zenbook Duo UX8406MA audio configuration
# Realtek ALC294 + CS35L41 smart amplifiers
options snd-hda-intel model=asus-zenbook
options snd-sof-intel-hda-common hda_model=asus-zenbook
EOF
echo "  Kernel audio options configured"

# Run audio calibration
if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" "$BIN_DIR/audio-calibrate.sh" 2>/dev/null || true
fi

# --- WiFi Configuration -----------------------------------------------------

echo ""
echo "[5/8] Configuring WiFi..."

cat > /etc/modprobe.d/iwlwifi-zenbook.conf << 'EOF'
# Intel Meteor Lake CNVi WiFi - Zenbook Duo UX8406MA
# Disable power save to prevent soft lockups
options iwlwifi power_save=0 bt_coex_active=1
EOF
echo "  WiFi driver options configured"

# --- Configure Hotkeys ------------------------------------------------------

echo ""
echo "[6/8] Configuring keyboard hotkeys..."

if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" "$BIN_DIR/setup-hotkeys.sh" 2>/dev/null || true
    echo "  Hotkeys configured for $INSTALL_USER"
fi

# --- Configure Touch Mapping (Wayland) --------------------------------------

echo ""
echo "[7/8] Configuring touch mapping..."

# Apply touch mapping for Wayland
if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" bash -c '
        dconf write /org/gnome/desktop/peripherals/tablets/04f3:425b/output "['\''SDC'\'', '\''0x419d'\'', '\''0x00000000'\'', '\''eDP-1'\'']" 2>/dev/null
        dconf write /org/gnome/desktop/peripherals/tablets/04f3:425a/output "['\''SDC'\'', '\''0x419d'\'', '\''0x00000000'\'', '\''eDP-2'\'']" 2>/dev/null
        dconf write /org/gnome/desktop/peripherals/touchscreens/04f3:425b/output "['\''SDC'\'', '\''0x419d'\'', '\''0x00000000'\'', '\''eDP-1'\'']" 2>/dev/null
        dconf write /org/gnome/desktop/peripherals/touchscreens/04f3:425a/output "['\''SDC'\'', '\''0x419d'\'', '\''0x00000000'\'', '\''eDP-2'\'']" 2>/dev/null
    ' 2>/dev/null || true
    echo "  Touch mapping configured for Wayland"
fi

# --- Security and Systemd ---------------------------------------------------

echo ""
echo "[8/8] Setting up security and services..."

# Udev rules for keyboard backlight
cat > /etc/udev/rules.d/99-zenbook-keyboard.rules << 'EOF'
# ASUS Zenbook Duo Keyboard - USB access without root
SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1b2c", MODE="0666", GROUP="plugdev"
EOF
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true
echo "  Udev rules configured"

# Restricted sudoers
if [ -n "$INSTALL_USER" ]; then
    cat > /etc/sudoers.d/zenbook-duo << EOF
# Zenbook Duo - Limited sudo access for hardware control
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT0/charge_control_end_threshold
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/backlight/*/brightness
$INSTALL_USER ALL=(root) NOPASSWD: /usr/local/bin/bk.py *
$INSTALL_USER ALL=(root) NOPASSWD: /usr/local/bin/fn-lock.py *
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill block bluetooth
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill unblock bluetooth
EOF
    chmod 0440 /etc/sudoers.d/zenbook-duo
    echo "  Sudoers configured for $INSTALL_USER"
fi

# Install systemd services
cp "$REPO_DIR/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload

# Enable all services
SERVICES="zenbook-duo.service brightness-sync.service zenbook-auto-display.service zenbook-light-monitor.service zenbook-thermal.service zenbook-adaptive-brightness.service zenbook-config.service"
for svc in $SERVICES; do
    systemctl enable "$svc" 2>/dev/null && echo "  Enabled: $svc" || echo "  WARNING: Failed to enable $svc"
done

# Start daemon immediately
systemctl restart zenbook-duo.service 2>/dev/null || true

# Create GNOME autostart
if [ -n "$INSTALL_USER" ]; then
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
    chown "$INSTALL_USER:$INSTALL_USER" "$AUTOSTART_DIR/zenbook-duo.desktop"
    echo "  GNOME autostart configured"
fi

# --- Finalize ---------------------------------------------------------------

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
if [ $ERRORS -gt 0 ]; then
    echo "  WARNING: $ERRORS error(s) occurred during installation."
    echo "  Check the output above for details."
    echo ""
fi
echo "  Services installed:"
systemctl list-unit-files | grep zenbook | awk '{print "    - " $1}'
echo ""
echo "  To finish setup:"
echo "    1. Restart your session (Log out and back in)"
echo "    2. Run 'duo help' to see available commands"
echo "    3. Run 'test_hardware.sh' to verify hardware"
echo "    4. Open EasyEffects and select the 'ZenbookDuo' profile"
echo ""
