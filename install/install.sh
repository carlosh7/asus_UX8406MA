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

echo "[1/7] Installing dependencies for $OS..."

install_pkg() {
    local pkg="$1"
    if command -v "$pkg" &>/dev/null || dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        apt-get update -qq

        # Critical dependencies - abort if these fail
        CRITICAL_PKGS="python3 python3-usb python3-dbus inotify-tools usbutils build-essential gcc make pkg-config libusb-1.0-0-dev libglib2.0-dev iw xdotool"
        echo "  Installing critical packages..."
        if ! apt-get install -y -qq $CRITICAL_PKGS 2>/dev/null; then
            echo "ERROR: Failed to install critical dependencies."
            echo "  Try: sudo apt-get install $CRITICAL_PKGS"
            ERRORS=$((ERRORS + 1))
        fi

        # Optional dependencies - warn but continue
        OPTIONAL_PKGS="lm-sensors iio-sensor-proxy easyeffects lsp-plugins"
        echo "  Installing optional packages..."
        apt-get install -y -qq $OPTIONAL_PKGS 2>/dev/null || {
            echo "  WARNING: Some optional packages failed to install."
            echo "  Audio features (EasyEffects) may not work."
        }
        ;;
    arch|manjaro|endeavouros)
        pacman -Sy --noconfirm

        CRITICAL_PKGS="python python-pyusb python-dbus inotify-tools usbutils base-devel libusb glib2 iw xdotool"
        echo "  Installing critical packages..."
        if ! pacman -S --noconfirm $CRITICAL_PKGS 2>/dev/null; then
            echo "ERROR: Failed to install critical dependencies."
            ERRORS=$((ERRORS + 1))
        fi

        OPTIONAL_PKGS="lm_sensors iio-sensor-proxy easyeffects lsp-plugins"
        echo "  Installing optional packages..."
        pacman -S --noconfirm $OPTIONAL_PKGS 2>/dev/null || {
            echo "  WARNING: Some optional packages failed to install."
        }
        ;;
    *)
        echo "WARNING: Unsupported OS: $OS. Please install dependencies manually."
        echo "  Required: python3 python3-usb python3-dbus inotify-tools usbutils iw xdotool"
        ;;
esac

# Verify critical tools
echo "  Verifying installation..."
MISSING=""
for tool in python3 inotifywait iw xdotool lsusb; do
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
echo "[2/7] Compiling and installing the daemon..."
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
echo "[3/7] Installing CLI scripts..."

# Core scripts
CORE_SCRIPTS="duo bk.py fn-lock.py wayland-display-mgr.py"
for script in $CORE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

# Service scripts
SERVICE_SCRIPTS="auto-display.sh light-monitor.sh start.sh toggle-bluetooth.sh kb-light-cycle.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-mgr.sh"
for script in $SERVICE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

# Test script
if [ -f "$REPO_DIR/scripts/test_hardware.sh" ]; then
    cp "$REPO_DIR/scripts/test_hardware.sh" "$BIN_DIR/"
    chmod +x "$BIN_DIR/test_hardware.sh"
fi

echo "  Installed $(ls "$BIN_DIR"/{duo,bk.py,fn-lock.py,wayland-display-mgr.py} 2>/dev/null | wc -l) core scripts"

# --- Configure Audio --------------------------------------------------------

echo ""
echo "[4/7] Configuring audio optimizations..."

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

# --- WiFi Configuration -----------------------------------------------------

echo ""
echo "[5/7] Configuring WiFi..."

cat > /etc/modprobe.d/iwlwifi-zenbook.conf << 'EOF'
# Intel Meteor Lake CNVi WiFi - Zenbook Duo UX8406MA
# Disable power save to prevent soft lockups
options iwlwifi power_save=0 bt_coex_active=1
EOF
echo "  WiFi driver options configured"

# --- Security and Systemd ---------------------------------------------------

echo ""
echo "[6/7] Setting up security and services..."

# Restricted sudoers (only specific commands needed by zenbook-duo)
if [ -n "$INSTALL_USER" ]; then
    cat > /etc/sudoers.d/zenbook-duo << EOF
# Zenbook Duo - Limited sudo access for hardware control
# Created by zenbook-duo installer
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT0/charge_control_end_threshold
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/backlight/*/brightness
$INSTALL_USER ALL=(root) NOPASSWD: /usr/local/bin/bk.py *
$INSTALL_USER ALL=(root) NOPASSWD: /usr/local/bin/fn-lock.py *
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill block bluetooth
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill unblock bluetooth
EOF
    chmod 0440 /etc/sudoers.d/zenbook-duo
    echo "  Sudoers configured for $INSTALL_USER (restricted access)"
else
    echo "  WARNING: Sudoers not configured (no user detected)"
fi

# Install systemd services
cp "$REPO_DIR/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload

# Enable services
SERVICES="zenbook-duo.service brightness-sync.service zenbook-auto-display.service zenbook-light-monitor.service"
for svc in $SERVICES; do
    systemctl enable "$svc" 2>/dev/null && echo "  Enabled: $svc" || echo "  WARNING: Failed to enable $svc"
done

# Start daemon immediately
systemctl restart zenbook-duo.service 2>/dev/null || true

# Create GNOME autostart (for user-level tools)
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
echo "[7/7] Finalizing hardware settings..."

# Set battery limit
echo 80 | tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null 2>&1 || true
echo "  Battery limit: 80%"

# Set audio levels
amixer -c 0 sset Master 100% 2>/dev/null || true
amixer -c 0 sset Speaker 100% 2>/dev/null || true
echo "  Audio levels set"

# --- Summary ----------------------------------------------------------------

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
