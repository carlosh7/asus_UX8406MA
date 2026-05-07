#!/bin/bash

echo "=============================================="
echo "  Zenbook Duo Linux - Hardware Test"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

test_ok() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "=== System Info ==="
uname -a
echo ""

echo "=== Hardware Detection ==="

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
    test_fail "Bluetooth adapter not found"
fi

# Webcam
if lsusb 2>/dev/null | grep -q "3277:0055"; then
    test_ok "Webcam detected"
else
    test_warn "Webcam not detected"
fi

echo ""
echo "=== Scripts Test ==="

# duo command
if command -v duo &> /dev/null; then
    test_ok "duo command available"
else
    test_fail "duo not in PATH"
fi

# bk.py
if command -v bk.py &> /dev/null || [ -f /usr/local/bin/bk.py ]; then
    test_ok "bk.py available"
else
    test_fail "bk.py not found"
fi

echo ""
echo "=== Display Test ==="

# Check displays
if command -v gnome-monitor-config &> /dev/null; then
    if gnome-monitor-config list 2>/dev/null | grep -q "eDP"; then
        test_ok "Displays detected via gnome-monitor-config"
    else
        test_fail "No eDP displays found"
    fi
else
    test_warn "gnome-monitor-config not available"
fi

# Test duo commands
duo model &>/dev/null && test_ok "duo model works" || test_fail "duo model failed"

echo ""
echo "=== Brightness Test ==="

# Check backlight paths
if [ -d /sys/class/backlight/intel_backlight ]; then
    test_ok "Main backlight path exists"
else
    test_fail "Main backlight path not found"
fi

if ls /sys/class/backlight/ | grep -q "eDP"; then
    test_ok "Secondary backlight path exists"
else
    test_warn "Secondary backlight not found"
fi

echo ""
echo "=== Battery Test ==="

if [ -d /sys/class/power_supply/BAT0 ]; then
    test_ok "Battery detected"
    if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
        test_ok "Battery charge limit supported"
    else
        test_warn "Charge limit not supported"
    fi
else
    test_fail "Battery not found"
fi

echo ""
echo "=== Keyboard Backlight Test ==="

# Test bk.py (without actually changing, just check it runs)
python3 /usr/local/bin/bk.py 2>&1 | head -1 | grep -q "Usage\|level\|Device" && test_ok "bk.py executes" || test_warn "bk.py may need sudo"

echo ""
echo "=== Results ==="
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check output above.${NC}"
    exit 1
fi