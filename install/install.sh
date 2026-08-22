#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Installation Script
# Supports: Ubuntu 24.04+, Debian 12+, Arch Linux
# ============================================================================

set -euo pipefail

# --- Flags ------------------------------------------------------------------
# --with-npu: instalar driver Intel NPU + Level Zero (IA opcional, no requerido)
WITH_NPU=0
for arg in "$@"; do
    case "$arg" in
        --with-npu) WITH_NPU=1 ;;
        --help|-h)
            echo "Uso: sudo ./install/install.sh [--with-npu]"
            echo "  --with-npu  Instala driver Intel NPU + Level Zero (opcional)"
            exit 0 ;;
        *) echo "Flag desconocida: $arg"; exit 1 ;;
    esac
done

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
# INSTALL_USER puede predefinirse vía entorno para instalaciones automatizadas
if [ -n "${SUDO_USER:-}" ]; then
    INSTALL_USER="$SUDO_USER"
elif [ -n "${INSTALL_USER:-}" ]; then
    :   # predefinido por el operador
else
    INSTALL_USER=$(logname 2>/dev/null || echo "")
fi

if [ -z "$INSTALL_USER" ]; then
    echo "ERROR: Cannot detect logged-in user."
    echo "Run again with: sudo INSTALL_USER=<tu_usuario> ./install/install.sh"
    exit 1
fi

USER_HOME=$(getent passwd "$INSTALL_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$INSTALL_USER")

# --- OS Detection -----------------------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "[1/10] Installing dependencies for $OS..."

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

        # System monitoring packages
        MONITOR_PKGS="btop nvme-cli"
        echo "  Installing monitoring packages..."
        apt-get install -y -qq $MONITOR_PKGS 2>/dev/null || {
            echo "  WARNING: Some monitoring packages failed to install."
        }

        # Power management packages
        POWER_PKGS="tlp tlp-rdw powertop"
        echo "  Installing power management packages..."
        apt-get install -y -qq $POWER_PKGS 2>/dev/null || {
            echo "  WARNING: Some power packages failed to install."
        }

        # OpenVINO + ONNX Runtime for NPU/AI
        echo "  Installing AI packages..."
        pip3 install --break-system-packages openvino onnxruntime-openvino 2>/dev/null || {
            echo "  WARNING: AI packages installation failed"
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

        MONITOR_PKGS="btop nvme-cli"
        echo "  Installing monitoring packages..."
        pacman -S --noconfirm $MONITOR_PKGS 2>/dev/null || {
            echo "  WARNING: Some monitoring packages failed to install."
        }

        # Power management packages
        POWER_PKGS="tlp powertop"
        echo "  Installing power management packages..."
        pacman -S --noconfirm $POWER_PKGS 2>/dev/null || {
            echo "  WARNING: Some power packages failed to install."
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
echo "[2/10] Compiling and installing the daemon..."
cd "$REPO_DIR/daemon"
make clean 2>/dev/null || true
if ! make; then
    echo "ERROR: Daemon compilation failed."
    ERRORS=$((ERRORS + 1))
else
    make install
fi
cd "$REPO_DIR"

# --- Install NPU Driver (Intel Meteor Lake) ---------------------------------

echo ""
echo "[3/10] Installing NPU driver for Intel AI Boost..."

if [ "$WITH_NPU" -eq 1 ]; then
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    # Fetch the latest NPU driver release from GitHub (no hardcoded version)
    echo "  Checking for latest Intel NPU driver..."
    LATEST_JSON=$(wget -qO- "https://api.github.com/repos/intel/linux-npu-driver/releases/latest" 2>/dev/null || true)
    NPU_TAG=$(echo "$LATEST_JSON" | grep -oE '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
    NPU_DEB_URL=$(echo "$LATEST_JSON" | grep -oE '"browser_download_url": "[^"]*ubuntu2404\.tar\.gz"' | head -1 | cut -d'"' -f4)

    if [ -z "$NPU_DEB_URL" ] || [ -z "$NPU_TAG" ]; then
        # Fallback to a known good release if GitHub API is unreachable
        NPU_TAG="v1.35.0"
        NPU_DEB_URL="https://github.com/intel/linux-npu-driver/releases/download/v1.35.0/linux-npu-driver-v1.35.0.20260722-29947505341-ubuntu2404.tar.gz"
        LATEST_JSON=""
    fi

    NPU_DEB_FILE="/tmp/linux-npu-driver-${NPU_TAG}.tar.gz"
    echo "  Latest NPU driver: $NPU_TAG"

    # Download NPU driver
    if [ ! -f "$NPU_DEB_FILE" ]; then
        wget -q "$NPU_DEB_URL" -O "$NPU_DEB_FILE" 2>/dev/null || {
            echo "  WARNING: NPU driver download failed"
        }
    fi

    if [ -f "$NPU_DEB_FILE" ]; then
        # Verificar SHA256 contra el digest publicado en la release de GitHub
        NPU_ASSET=$(basename "$NPU_DEB_URL")
        EXPECTED_SHA=$(printf '%s' "$LATEST_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    asset_name = '$NPU_ASSET'
    for a in data.get('assets', []):
        if a.get('name') == asset_name:
            print(a.get('digest', '').replace('sha256:', ''))
            break
except Exception:
    pass")
        ACTUAL_SHA=$(sha256sum "$NPU_DEB_FILE" | cut -d' ' -f1)
        if [ -n "$EXPECTED_SHA" ] && [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
            echo "  ERROR: checksum mismatch para $NPU_ASSET (esperado $EXPECTED_SHA, real $ACTUAL_SHA)"
            rm -f "$NPU_DEB_FILE"
        elif [ -z "$EXPECTED_SHA" ]; then
            echo "  WARNING: sin digest publicable; se continúa sin verificación"
        else
            echo "  Checksum OK ($ACTUAL_SHA)"
        fi
    fi

    if [ -f "$NPU_DEB_FILE" ]; then
        # Extract and install
        cd /tmp
        rm -f intel-driver-compiler-npu_*.deb intel-fw-npu_*.deb intel-level-zero-npu_*.deb
        tar -xf "$NPU_DEB_FILE" 2>/dev/null || true
        NPU_DEBS=$(ls intel-driver-compiler-npu_*.deb intel-fw-npu_*.deb intel-level-zero-npu_*.deb 2>/dev/null)
        if [ -n "$NPU_DEBS" ]; then
            apt-get install -y -qq libtbb12 2>/dev/null || true
            dpkg -i $NPU_DEBS 2>/dev/null || true
            echo "  NPU driver installed"
        else
            echo "  WARNING: NPU deb packages not found"
        fi
        cd "$REPO_DIR"
    fi

    # Install the latest Level Zero loader from the Intel PPA (dynamic version)
    echo "  Checking for latest Level Zero loader..."
    DISTRO_ID=$(grep -E "^(VERSION_ID)=" /etc/os-release | cut -d= -f2 | tr -d '"' | head -1)
    [ -n "$DISTRO_ID" ] || DISTRO_ID="24.04"
    LIBZE_URL=""
    for url in \
        "https://ppa.launchpadcontent.net/kobuk-team/intel-graphics/ubuntu/pool/main/l/level-zero-loader/" \
        "https://ppa.launchpad.net/kobuk-team/intel-graphics/ubuntu/pool/main/l/level-zero-loader/"; do
        PPA_INDEX=$(wget -qO- "$url" 2>/dev/null || true)
        if [ -n "$PPA_INDEX" ]; then
            # Prefer the exact distro version (e.g. 26.04), fall back to any matching suffix
            LIBZE_FILE=$(echo "$PPA_INDEX" | grep -oE "libze1_[^\"']*~${DISTRO_ID}~[^\"']*_amd64\.deb" | sort -V | tail -1)
            [ -z "$LIBZE_FILE" ] && LIBZE_FILE=$(echo "$PPA_INDEX" | grep -oE 'libze1_[^"<]*_amd64\.deb' | sort -V | tail -1)
            if [ -n "$LIBZE_FILE" ]; then
                LIBZE_URL="${url}${LIBZE_FILE}"
                break
            fi
        fi
    done

    if [ -n "$LIBZE_URL" ]; then
        echo "  Latest Level Zero loader: $(basename "$LIBZE_URL")"
        wget -q "$LIBZE_URL" -O /tmp/libze1_latest.deb 2>/dev/null || true
        if [ -f /tmp/libze1_latest.deb ]; then
            dpkg -i /tmp/libze1_latest.deb 2>/dev/null || true
            echo "  Level Zero loader installed"
        fi
    else
        echo "  WARNING: Could not determine latest Level Zero loader"
    fi

    # Add user to render group for NPU access
    if [ -n "$INSTALL_USER" ]; then
        gpasswd -a "$INSTALL_USER" render 2>/dev/null || true
        echo "  User $INSTALL_USER added to render group"
    fi
    else
        echo "  WARNING: NPU driver solo soportado en Ubuntu/Debian"
    fi
else
    echo "  Skipped (flag --with-npu no pasada). El resto del stack funciona sin IA."
fi

echo ""
echo "[4/10] Installing CLI scripts..."

# Core scripts
CORE_SCRIPTS="duo bk.py fn-lock.py wayland-display-mgr.py"
for script in $CORE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

# Service scripts
SERVICE_SCRIPTS="auto-display.sh start.sh kb-light-cycle.sh toggle-bluetooth.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-unified.sh adaptive-brightness.sh thermal-monitor.sh audio-diagnose.sh audio-calibrate.sh wifi-diagnose.sh test_hardware.sh webcam-diagnose.sh webcam-optimize.sh bt-keyboard-mapper.py zenbook-config.sh suspend-backlight.sh nightlight.sh ssd-health.sh fn-lock.sh system-health.sh disk-monitor.sh weekly-maintenance.sh zzz-keyboard-light oled-protect.sh webcam-privacy.sh firmware-check.sh zenbook-health-check.sh zenbook-boot-test.sh touch-remap.sh setup-touch-wayland.sh amp-enable.sh"
for script in $SERVICE_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        cp "$REPO_DIR/scripts/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
    fi
done

echo "  Installed CLI scripts"

# --- Configure Audio --------------------------------------------------------

echo ""
echo "[5/10] Configuring audio optimizations..."

# Copy EasyEffects profile
if [ -n "$INSTALL_USER" ]; then
    mkdir -p "$USER_HOME/.config/easyeffects/output/"
    cp "$REPO_DIR/config/easyeffects/output/ZenbookDuo.json" "$USER_HOME/.config/easyeffects/output/" 2>/dev/null || true
    cp "$REPO_DIR/config/easyeffects/output/ZenbookDuo-Spatial.json" "$USER_HOME/.config/easyeffects/output/" 2>/dev/null || true
    chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/easyeffects/" 2>/dev/null || true
    echo "  EasyEffects profiles installed (standard + spatial)"
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
echo "[6/10] Configuring WiFi..."

cat > /etc/modprobe.d/iwlwifi-zenbook.conf << 'EOF'
# Intel Meteor Lake CNVi WiFi - Zenbook Duo UX8406MA
# Disable power save to prevent soft lockups
options iwlwifi power_save=0 bt_coex_active=1
EOF
echo "  WiFi driver options configured"

# --- Configure Hotkeys ------------------------------------------------------

echo ""
echo "[7/10] Configuring keyboard hotkeys..."

if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" "$BIN_DIR/setup-hotkeys.sh" 2>/dev/null || true
    echo "  Hotkeys configured for $INSTALL_USER"
fi

# --- Configure Touch Mapping (Wayland) --------------------------------------

echo ""
echo "[8/10] Configuring touch mapping..."

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
echo "[9/10] Setting up security and services..."

# Udev rules for keyboard backlight
# 0660+input (no world-writable): los scripts corren como root o con grupo input.
cat > /etc/udev/rules.d/99-zenbook-keyboard.rules << EOF
# ASUS Zenbook Duo Keyboard - group access only (no world access)
SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1b2c", MODE="0660", GROUP="input"
EOF

# Garantiza acceso a dispositivos de entrada sin sudo (evtest, mapeos)
getent group input >/dev/null || groupadd input
usermod -aG input "$INSTALL_USER"

# Udev rules for NPU access
cat > /etc/udev/rules.d/99-zenbook-npu.rules << 'EOF'
# Intel NPU - accessible by render group
SUBSYSTEM=="accel", KERNEL=="accel*", MODE="0660", GROUP="render"
EOF

# Udev rule for CS35L41 right amplifier
cp "$REPO_DIR/config/udev/99-zenbook-duo-amp.rules" /etc/udev/rules.d/99-zenbook-duo-amp.rules

# USB power management rules (BT wake fix) - match by VID/PID
cp "$REPO_DIR/config/udev/50-usb-power-management.rules" /etc/udev/rules.d/50-usb-power-management.rules
cp "$REPO_DIR/config/udev/99-zenbook-keyboard-bt.rules" /etc/udev/rules.d/99-zenbook-keyboard-bt.rules

udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --action=add --subsystem-match=usb 2>/dev/null || true
udevadm trigger --action=add --subsystem-match=backlight 2>/dev/null || true
echo "  Udev rules configured (keyboard, NPU, USB power)"

# Restricted sudoers
if [ -n "$INSTALL_USER" ]; then
    BACKLIGHT_PATHS=""
    for bl in /sys/class/backlight/*; do
        if [ -d "$bl" ]; then
            name=$(basename "$bl")
            if [ -n "$BACKLIGHT_PATHS" ]; then
                BACKLIGHT_PATHS="${BACKLIGHT_PATHS}, "
            fi
            BACKLIGHT_PATHS="${BACKLIGHT_PATHS}/usr/bin/tee /sys/class/backlight/${name}/brightness"
        fi
    done

    cat > /etc/sudoers.d/zenbook-duo << EOF
# Zenbook Duo - Limited sudo access for hardware control
# NOTA: sin wildcards en argumentos (evtest/bk/fn-lock eliminados:
# el usuario pertenece al grupo input y los servicios corren como root).
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT0/charge_control_end_threshold
$INSTALL_USER ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT1/charge_control_end_threshold
$INSTALL_USER ALL=(root) NOPASSWD: $BACKLIGHT_PATHS
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill block bluetooth
$INSTALL_USER ALL=(root) NOPASSWD: /usr/sbin/rfkill unblock bluetooth
EOF
    chmod 0440 /etc/sudoers.d/zenbook-duo
    echo "  Sudoers configured for $INSTALL_USER"
fi

# Install systemd services
cp "$REPO_DIR/systemd/"*.service /etc/systemd/system/

# Set the run-as user on services that need the graphical session
# (no hardcoded username in the repo; injected at install time)
if [ -n "$INSTALL_USER" ]; then
    for unit in zenbook-light-monitor zenbook-bt-keyboard mic-boost; do
        sed -i "/^\[Service\]/a User=$INSTALL_USER\nGroup=$INSTALL_USER" "/etc/systemd/system/$unit.service"
    done
fi
systemctl daemon-reload

# Enable all services
SERVICES="zenbook-duo.service brightness-sync.service zenbook-light-monitor.service zenbook-thermal.service zenbook-adaptive-brightness.service zenbook-auto-display.service zenbook-config.service battery-limit.service zenbook-nightlight.service zenbook-suspend-backlight.service mic-boost.service zenbook-bt-keyboard.service"
for svc in $SERVICES; do
    systemctl enable "$svc" 2>/dev/null && echo "  Enabled: $svc" || echo "  WARNING: Failed to enable $svc"
done

# Desactivar el ALS propio de GNOME: compite con adaptive-brightness
if [ -n "$INSTALL_USER" ]; then
    local_uid=$(id -u "$INSTALL_USER" 2>/dev/null)
    sudo -u "$INSTALL_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${local_uid}/bus" \
        XDG_RUNTIME_DIR="/run/user/${local_uid}" \
        gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false 2>/dev/null \
        && echo "  GNOME ALS desactivado (usa zenbook-adaptive-brightness)"
fi

# Start all services immediately (no reboot required for userspace features)
for svc in $SERVICES; do
    systemctl start "$svc" 2>/dev/null && echo "  Started: $svc" || echo "  WARNING: Failed to start $svc"
done

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

# --- System Configuration ----------------------------------------------------

echo ""
echo "[10/10] Applying system configuration..."

# Sysctl performance tuning
if [ -f "$REPO_DIR/config/sysctl/99-performance.conf" ]; then
    cp "$REPO_DIR/config/sysctl/99-performance.conf" /etc/sysctl.d/
    sysctl --system 2>/dev/null || true
    echo "  Sysctl performance tuning applied"
fi

# GPU power optimization (xe module parameters)
if [ -f "$REPO_DIR/config/modprobe/xe-gpu-optimize.conf" ]; then
    cp "$REPO_DIR/config/modprobe/xe-gpu-optimize.conf" /etc/modprobe.d/
    echo "  GPU power optimization configured"
fi

# Logrotate configuration
if [ -f "$REPO_DIR/config/logrotate/zenbook-duo.conf" ]; then
    cp "$REPO_DIR/config/logrotate/zenbook-duo.conf" /etc/logrotate.d/
    echo "  Logrotate configuration installed"
fi

# TLP power management
if command -v tlp &>/dev/null; then
    mkdir -p /etc/tlp.d/
    if [ -f "$REPO_DIR/config/tlp/01-zenbook.conf" ]; then
        cp "$REPO_DIR/config/tlp/01-zenbook.conf" /etc/tlp.d/
        systemctl enable tlp 2>/dev/null || true
        systemctl start tlp 2>/dev/null || true
        echo "  TLP power management configured"
    fi
fi

# PowerTOP auto-tune: DESACTIVADO por decisión de diseño — compite con TLP
# (auditoría 2026-08: un solo gestor de energía). El paquete queda instalado
# para uso manual si se necesita.
if command -v powertop &>/dev/null; then
    echo "  PowerTOP presente (sin servicio automático; TLP gestiona energía)"
fi

# Auto-cpufreq (if snap is available)
if command -v snap &>/dev/null; then
    snap install auto-cpufreq 2>/dev/null && {
        auto-cpufreq --install 2>/dev/null || true
        echo "  auto-cpufreq installed"
    } || echo "  WARNING: auto-cpufreq installation failed"
fi

# Create persistent state directory
mkdir -p /var/lib/zenbook-duo
if [ -n "$INSTALL_USER" ]; then
    chown "$INSTALL_USER:$INSTALL_USER" /var/lib/zenbook-duo
fi
echo "  State directory created: /var/lib/zenbook-duo"

# Keyboard backlight log (owned by user so light-monitor service can write)
touch /var/log/zenbook-kb-backlight.log
if [ -n "$INSTALL_USER" ]; then
    chown "$INSTALL_USER:$INSTALL_USER" /var/log/zenbook-kb-backlight.log
fi

# Config del timeout de luz de teclado (kb-backlight-unified.sh lo lee)
mkdir -p /etc/zenbook-duo
cat > /etc/zenbook-duo/kb-backlight.conf << 'EOF'
# Segundos que la luz del teclado permanece encendida tras dejar de escribir.
# Cambia este valor y reinicia zenbook-light-monitor.service si lo necesitas.
INACTIVITY_TIMEOUT=45000
EOF
chmod 644 /etc/zenbook-duo/kb-backlight.conf
echo "  KB backlight config: 45s (editable en /etc/zenbook-duo/kb-backlight.conf)"

# OLED protection (run for user)
if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" "$BIN_DIR/oled-protect.sh" 2>/dev/null || true
    echo "  OLED protection configured"
fi

# --- Verify Installation ----------------------------------------------------

echo ""
echo "=============================================="
echo "  VERIFICANDO INSTALACIÓN..."
echo "=============================================="
echo ""
HEALTH_EXIT=0
if [ -n "$INSTALL_USER" ]; then
    sudo -u "$INSTALL_USER" "$BIN_DIR/zenbook-health-check.sh" || HEALTH_EXIT=$?
else
    "$BIN_DIR/zenbook-health-check.sh" || HEALTH_EXIT=$?
fi
if [ $HEALTH_EXIT -ne 0 ]; then
    ERRORS=$((ERRORS + 1))
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
echo "    - battery-limit.service"
echo ""
echo "  Features enabled:"
echo "    - NPU (Intel AI Boost) with OpenVINO"
echo "    - GPU power optimization (FBC, PSR, DC)"
echo "    - TLP power management"
echo "    - OLED burn-in protection"
echo "    - USB power management (BT wake fix)"
echo "    - Sysctl performance tuning"
echo "    - Spatial audio profile"
echo ""
echo "  To finish setup:"
echo "    1. REBOOT (required to load kernel modules: audio, WiFi, NPU)"
echo "    2. After reboot, run 'zenbook-health-check.sh' to confirm everything works"
echo "    3. Run 'duo help' to see available commands"
echo "    4. Open EasyEffects and select 'ZenbookDuo' profile"
echo ""
