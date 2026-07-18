#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Complete Hardware Test
# Tests: display, audio, thermal, WiFi, keyboard, battery, services
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

test_ok() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
test_fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }
test_warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }

echo "=============================================="
echo "  Zenbook Duo Linux - Complete Hardware Test"
echo "=============================================="
echo ""

# --- System Info ------------------------------------------------------------

echo -e "${BLUE}=== System Info ===${NC}"
echo "  $(uname -r)"
echo "  $(cat /etc/os-release 2>/dev/null | grep "PRETTY_NAME" | cut -d'"' -f2)"
echo ""

# --- USB Devices ------------------------------------------------------------

echo -e "${BLUE}=== Hardware Detection ===${NC}"

# USB Keyboard
if lsusb 2>/dev/null | grep -q "0b05:1b2c"; then
    test_ok "Keyboard USB detected"
else
    test_fail "Keyboard USB not found"
fi

# Bluetooth
if lsusb 2>/dev/null | grep -q "8087:0033"; then
    test_ok "Bluetooth adapter detected"
else
    test_warn "Bluetooth adapter not found"
fi

# Webcam
if lsusb 2>/dev/null | grep -q "3277:0055"; then
    test_ok "Webcam detected"
else
    test_warn "Webcam not detected"
fi

# WiFi
if lspci 2>/dev/null | grep -qi "network\|wifi"; then
    test_ok "WiFi adapter detected"
else
    test_fail "WiFi adapter not found"
fi

echo ""

# --- Display System ---------------------------------------------------------

echo -e "${BLUE}=== Display System ===${NC}"

# duo command
if command -v duo &>/dev/null; then
    test_ok "duo command available"
else
    test_fail "duo not in PATH"
fi

# Model detection
MODEL=$(duo model 2>/dev/null)
if [ "$MODEL" = "3k" ] || [ "$MODEL" = "1080p" ]; then
    test_ok "Model detected: $MODEL"
else
    test_fail "Model detection failed"
fi

# Session type
SESSION=$(duo session-type 2>/dev/null)
if echo "$SESSION" | grep -qiE "wayland|x11"; then
    test_ok "Session: $SESSION"
else
    test_warn "Session detection unclear"
fi

# Display status
STATUS=$(duo status 2>/dev/null)
if [ -n "$STATUS" ]; then
    test_ok "Display status: $STATUS"
else
    test_fail "Cannot get display status"
fi

# External monitor support
if command -v python3 &>/dev/null && python3 -c "import dbus" 2>/dev/null; then
    test_ok "DBus available (external monitor support)"
else
    test_warn "python3-dbus not available"
fi

echo ""

# --- Brightness System ------------------------------------------------------

echo -e "${BLUE}=== Brightness System ===${NC}"

# Main backlight
if [ -d /sys/class/backlight/intel_backlight ]; then
    MAIN_BL=$(cat /sys/class/backlight/intel_backlight/brightness 2>/dev/null)
    test_ok "Main backlight: $MAIN_BL"
else
    test_fail "Main backlight path not found"
fi

# Secondary backlight
if ls /sys/class/backlight/ | grep -q "eDP"; then
    SEC_BL=$(cat /sys/class/backlight/card1-eDP-2-backlight/brightness 2>/dev/null)
    test_ok "Secondary backlight: $SEC_BL"
else
    test_warn "Secondary backlight not found"
fi

# inotifywait
if command -v inotifywait &>/dev/null; then
    test_ok "inotifywait available"
else
    test_warn "inotifywait not found (watch-backlight won't work)"
fi

echo ""

# --- Keyboard ---------------------------------------------------------------

echo -e "${BLUE}=== Keyboard ===${NC}"

# bk.py
if command -v bk.py &>/dev/null || [ -f /usr/local/bin/bk.py ]; then
    test_ok "bk.py available"
    # Test execution
    python3 /usr/local/bin/bk.py 2>&1 | head -1 | grep -q "Usage\|level\|Device" && \
        test_ok "bk.py executes correctly" || test_warn "bk.py may need sudo"
else
    test_fail "bk.py not found"
fi

# fn-lock.py
if command -v fn-lock.py &>/dev/null || [ -f /usr/local/bin/fn-lock.py ]; then
    test_ok "fn-lock.py available"
else
    test_warn "fn-lock.py not found"
fi

echo ""

# --- Battery ----------------------------------------------------------------

echo -e "${BLUE}=== Battery ===${NC}"

if [ -d /sys/class/power_supply/BAT0 ]; then
    test_ok "Battery detected"
    
    if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
        THRESHOLD=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
        test_ok "Charge limit: ${THRESHOLD}%"
    else
        test_warn "Charge limit not supported"
    fi
    
    STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    test_ok "Battery: $STATUS, ${CAPACITY}%"
else
    test_fail "Battery not found"
fi

echo ""

# --- Audio ------------------------------------------------------------------

echo -e "${BLUE}=== Audio ===${NC}"

# PipeWire
if pgrep -x pipewire >/dev/null; then
    test_ok "PipeWire running"
else
    test_fail "PipeWire NOT running"
fi

# Speaker sink
DEFAULT_SINK=$(wpctl status 2>/dev/null | grep "\*.*Speaker" | head -1)
if [ -n "$DEFAULT_SINK" ]; then
    VOL=$(echo "$DEFAULT_SINK" | grep -oP 'vol: \K[0-9.]+')
    VOL_PCT=$(echo "$VOL" | awk '{printf "%d", $1 * 100}')
    if [ "$VOL_PCT" -le 100 ]; then
        test_ok "Speaker volume: ${VOL_PCT}%"
    else
        test_warn "Speaker volume: ${VOL_PCT}% (over-amplified!)"
    fi
else
    test_warn "Speaker sink not found"
fi

# EasyEffects
if command -v easyeffects &>/dev/null; then
    test_ok "EasyEffects installed"
    if [ -f "$HOME/.config/easyeffects/output/ZenbookDuo.json" ]; then
        if grep -q "calf" "$HOME/.config/easyeffects/output/ZenbookDuo.json" 2>/dev/null; then
            test_warn "EasyEffects profile uses unavailable Calf plugins"
        else
            test_ok "EasyEffects profile configured"
        fi
    else
        test_warn "ZenbookDuo profile not installed"
    fi
else
    test_warn "EasyEffects not installed"
fi

echo ""

# --- Thermal ----------------------------------------------------------------

echo -e "${BLUE}=== Thermal ===${NC}"

# CPU temperature
CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
if [ -n "$CPU_TEMP" ]; then
    TEMP_C=$(($CPU_TEMP / 1000))
    if [ "$TEMP_C" -lt 70 ]; then
        test_ok "CPU temperature: ${TEMP_C}°C (normal)"
    elif [ "$TEMP_C" -lt 85 ]; then
        test_warn "CPU temperature: ${TEMP_C}°C (warm)"
    else
        test_fail "CPU temperature: ${TEMP_C}°C (HOT!)"
    fi
fi

# Fan
FAN_SPEED=$(cat /sys/class/hwmon/hwmon7/fan1_input 2>/dev/null)
if [ -n "$FAN_SPEED" ]; then
    test_ok "Fan speed: ${FAN_SPEED} RPM"
fi

# Platform profile
PROFILE=$(cat /sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/platform-profile 2>/dev/null)
if [ -n "$PROFILE" ]; then
    test_ok "Thermal profile: $PROFILE"
fi

echo ""

# --- WiFi -------------------------------------------------------------------

echo -e "${BLUE}=== WiFi ===${NC}"

if lsmod | grep -q "iwlwifi"; then
    test_ok "iwlwifi driver loaded"
    
    PS=$(cat /sys/module/iwlwifi/parameters/power_save 2>/dev/null)
    if [ "$PS" = "0" ] || [ "$PS" = "N" ]; then
        test_ok "WiFi power save: OFF"
    else
        test_warn "WiFi power save: ON (may cause issues)"
    fi
fi

# Signal
SIGNAL=$(cat /proc/net/wireless 2>/dev/null | grep "wlo1" | awk '{print $4}' | tr -d '.')
if [ -n "$SIGNAL" ] && [ "$SIGNAL" -gt 0 ] 2>/dev/null; then
    if [ "$SIGNAL" -lt 60 ]; then
        test_ok "WiFi signal: -${SIGNAL} dBm (good)"
    else
        test_warn "WiFi signal: -${SIGNAL} dBm (weak)"
    fi
fi

echo ""

# --- Services ----------------------------------------------------------------

echo -e "${BLUE}=== Systemd Services ===${NC}"

for svc in zenbook-duo.service brightness-sync.service zenbook-auto-display.service zenbook-light-monitor.service zenbook-thermal.service; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        if systemctl is-active "$svc" &>/dev/null; then
            test_ok "$svc: active"
        else
            test_warn "$svc: enabled but not running"
        fi
    else
        test_warn "$svc: not installed"
    fi
done

echo ""

# --- Config Files -----------------------------------------------------------

echo -e "${BLUE}=== Configuration ===${NC}"

if [ -f /etc/zenbook-duo/zenbook-duo.conf ]; then
    test_ok "Daemon config exists"
else
    test_warn "Daemon config missing"
fi

if [ -f /etc/modprobe.d/zenbook-duo-audio.conf ]; then
    test_ok "Audio modprobe config exists"
else
    test_warn "Audio modprobe config missing"
fi

if [ -f /etc/sudoers.d/zenbook-duo ]; then
    test_ok "Sudoers config exists"
else
    test_warn "Sudoers config missing"
fi

echo ""

# --- Summary ----------------------------------------------------------------

echo "=============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "=============================================="

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "  ${RED}Some tests failed.${NC} Check output above for details."
    echo "  Run 'sudo ./install/install.sh' to fix common problems."
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Some warnings detected.${NC} System should work but may not be optimal."
    exit 0
else
    echo ""
    echo -e "  ${GREEN}All tests passed!${NC} System is healthy."
    exit 0
fi
