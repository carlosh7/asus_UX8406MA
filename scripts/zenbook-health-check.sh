#!/bin/bash
# ============================================================================
# Zenbook Duo - Post-Install Health Check
# Verifies all components are working after installation
# ============================================================================

ERRORS=0
WARNINGS=0

echo "╔══════════════════════════════════════════════════════╗"
echo "║       ZENBOOK DUO - POST-INSTALL HEALTH CHECK       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# 1. Services
echo "📦 SERVICIOS"
echo "────────────"
for svc in zenbook-duo zenbook-thermal zenbook-light-monitor zenbook-adaptive-brightness brightness-sync zenbook-config; do
    status=$(systemctl is-active ${svc}.service 2>/dev/null)
    if [ "$status" = "active" ]; then
        echo "  ✅ $svc"
    else
        echo "  ❌ $svc ($status)"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 2. ALS Sensor
echo "📷 SENSOR ALS"
echo "─────────────"
ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
if [ -n "$ALS_PATH" ] && [ -f "$ALS_PATH" ]; then
    ALS_VAL=$(cat "$ALS_PATH" 2>/dev/null)
    echo "  ✅ ALS sensor: $ALS_VAL ($ALS_PATH)"
else
    echo "  ❌ ALS sensor not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Keyboard
echo "⌨️  TECLADO"
echo "──────────"
if lsusb 2>/dev/null | grep -q "0b05:1b2c"; then
    echo "  ✅ USB keyboard attached"
else
    echo "  ⚠️  USB keyboard not attached (normal if using BT)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 4. Display
echo "🖥️  DISPLAY"
echo "──────────"
if [ -f /sys/class/drm/card0-eDP-1/status ]; then
    echo "  ✅ eDP-1: $(cat /sys/class/drm/card0-eDP-1/status)"
else
    echo "  ❌ eDP-1 not found"
    ERRORS=$((ERRORS + 1))
fi
if [ -f /sys/class/drm/card0-eDP-2/status ]; then
    echo "  ✅ eDP-2: $(cat /sys/class/drm/card0-eDP-2/status)"
else
    echo "  ⚠️  eDP-2 not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 5. Fan
echo "🌀 FAN"
echo "──────"
FAN_PATH=""
for hwmon in /sys/class/hwmon/hwmon*/name; do
    if [ "$(cat "$hwmon" 2>/dev/null)" = "asus" ]; then
        dir=$(dirname "$hwmon")
        if [ -f "$dir/fan1_input" ]; then
            FAN_PATH="$dir/fan1_input"
            break
        fi
    fi
done
if [ -n "$FAN_PATH" ]; then
    FAN_RPM=$(cat "$FAN_PATH" 2>/dev/null)
    echo "  ✅ Fan: ${FAN_RPM} RPM ($FAN_PATH)"
else
    echo "  ⚠️  Fan sensor not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 6. Battery
echo "🔋 BATERÍA"
echo "──────────"
BAT_LIMIT=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
BAT_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
if [ -n "$BAT_LIMIT" ]; then
    echo "  ✅ Charge limit: ${BAT_LIMIT}%"
else
    echo "  ❌ Charge limit not set"
    ERRORS=$((ERRORS + 1))
fi
echo "  📊 Current level: ${BAT_LEVEL}%"
echo ""

# 7. Audio
echo "🔊 AUDIO"
echo "────────"
if pactl info 2>/dev/null | grep -q "PipeWire"; then
    echo "  ✅ PipeWire active"
else
    echo "  ❌ PipeWire not active"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 8. Security
echo "🔒 SEGURIDAD"
echo "────────────"
UFW_STATUS=$(ufw status 2>/dev/null | head -1)
if echo "$UFW_STATUS" | grep -q "active"; then
    echo "  ✅ UFW: active"
else
    echo "  ❌ UFW: inactive"
    ERRORS=$((ERRORS + 1))
fi

SSH_STATUS=$(systemctl is-active ssh 2>/dev/null)
if [ "$SSH_STATUS" = "active" ]; then
    echo "  ✅ SSH: active"
else
    echo "  ⚠️  SSH: $SSH_STATUS"
    WARNINGS=$((WARNINGS + 1))
fi

FAIL2BAN=$(systemctl is-active fail2ban 2>/dev/null)
if [ "$FAIL2BAN" = "active" ]; then
    echo "  ✅ Fail2Ban: active"
else
    echo "  ❌ Fail2Ban: inactive"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 9. D-Bus Access
echo "📡 D-BUS"
echo "────────"
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "  ✅ Session bus: $DBUS_SESSION_BUS_ADDRESS"
else
    echo "  ⚠️  Session bus not set (normal for root)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 10. Thermal
echo "🌡️  THERMAL"
echo "──────────"
TEMP=$(cat /sys/class/thermal/thermal_zone13/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone12/temp 2>/dev/null)
PROFILE=$(cat /sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/profile 2>/dev/null)
if [ -n "$TEMP" ]; then
    echo "  ✅ CPU temp: $((TEMP/1000))°C"
else
    echo "  ❌ Cannot read CPU temp"
    ERRORS=$((ERRORS + 1))
fi
echo "  📊 Profile: $PROFILE"
echo ""

# Summary
echo "════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "  ✅ ALL CHECKS PASSED"
elif [ $ERRORS -eq 0 ]; then
    echo "  ⚠️  PASSED with $WARNINGS warning(s)"
else
    echo "  ❌ FAILED: $ERRORS error(s), $WARNINGS warning(s)"
fi
echo "════════════════════════════════════════════════════════"
