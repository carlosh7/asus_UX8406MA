#!/bin/bash
# ============================================================================
# Zenbook Duo - Automated Post-Reboot Test
# Runs after boot to verify everything works
# ============================================================================

LOG="/var/log/zenbook-boot-test.log"
ERRORS=0

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG" 2>/dev/null; }
fail() { echo "  ❌ $1"; log "FAIL: $1"; ERRORS=$((ERRORS + 1)); }
pass() { echo "  ✅ $1"; log "PASS: $1"; }

echo "╔══════════════════════════════════════════════════════╗"
echo "║     ZENBOOK DUO - POST-REBOOT AUTOMATED TEST        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
log "=== Boot test started ==="

# Wait for system to stabilize
sleep 10

# Test 1: Services running
echo "1. SERVICES"
for svc in zenbook-duo zenbook-thermal zenbook-light-monitor zenbook-adaptive-brightness brightness-sync zenbook-config; do
    if systemctl is-active ${svc}.service >/dev/null 2>&1; then
        pass "$svc"
    else
        fail "$svc not running"
    fi
done

# Test 2: ALS sensor readable
echo ""
echo "2. ALS SENSOR"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
if [ -n "$ALS_PATH" ] && [ -f "$ALS_PATH" ]; then
    VAL=$(cat "$ALS_PATH" 2>/dev/null)
    if [ "$VAL" -gt 0 ] 2>/dev/null; then
        pass "ALS readable: $VAL"
    else
        fail "ALS returns 0"
    fi
else
    fail "ALS sensor not found"
fi

# Test 3: Backlight responsive
echo ""
echo "3. KEYBOARD BACKLIGHT"
if python3 /usr/local/bin/bk.py 1 2>/dev/null; then
    pass "Backlight set to level 1"
    sleep 1
    python3 /usr/local/bin/bk.py 0 2>/dev/null
    pass "Backlight set to level 0"
else
    fail "Backlight not responding"
fi

# Test 4: Thermal monitor
echo ""
echo "4. THERMAL MONITOR"
TEMP=$(cat /sys/class/thermal/thermal_zone13/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone12/temp 2>/dev/null)
if [ -n "$TEMP" ] && [ "$TEMP" -gt 0 ] 2>/dev/null; then
    pass "CPU temp readable: $((TEMP/1000))°C"
else
    fail "Cannot read CPU temp"
fi

PROFILE=$(cat /sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/profile 2>/dev/null)
if [ -n "$PROFILE" ]; then
    pass "Platform profile: $PROFILE"
else
    fail "Cannot read platform profile"
fi

# Test 5: Battery
echo ""
echo "5. BATTERY"
BAT_LIMIT=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
if [ "$BAT_LIMIT" = "80" ]; then
    pass "Battery limit: 80%"
else
    fail "Battery limit: $BAT_LIMIT (expected 80)"
fi

# Test 6: Security
echo ""
echo "6. SECURITY"
if ufw status 2>/dev/null | grep -q "active"; then
    pass "UFW active"
else
    fail "UFW inactive"
fi

if systemctl is-active fail2ban >/dev/null 2>&1; then
    pass "Fail2Ban active"
else
    fail "Fail2Ban inactive"
fi

# Test 7: Display
echo ""
echo "7. DISPLAY"
if [ -f /sys/class/drm/card0-eDP-1/status ]; then
    pass "eDP-1: $(cat /sys/class/drm/card0-eDP-1/status)"
else
    fail "eDP-1 not found"
fi

# Test 8: D-Bus access (for light monitor)
echo ""
echo "8. D-BUS ACCESS"
DBUS_ADDR="unix:path=/run/user/1000/bus"
if [ -S "$DBUS_ADDR" ]; then
    pass "D-Bus session socket exists"
else
    fail "D-Bus session socket not found"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "  ✅ ALL TESTS PASSED"
    log "=== Boot test completed: ALL PASSED ==="
else
    echo "  ❌ $ERRORS TEST(S) FAILED"
    log "=== Boot test completed: $ERRORS FAILED ==="
fi
echo "════════════════════════════════════════════════════════"
