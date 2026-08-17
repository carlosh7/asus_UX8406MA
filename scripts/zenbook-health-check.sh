#!/bin/bash
# ============================================================================
# Zenbook Duo - Post-Install Health Check
# Verifies all components are working after installation
# Can be run as normal user or via sudo (auto-detects the graphical session)
# ============================================================================

ERRORS=0
WARNINGS=0
REBOOT_PENDING=0

# Detect graphical user/session (works when run as root)
detect_session() {
    local SID=""
    SID=$(loginctl list-sessions --no-legend 2>/dev/null | grep " seat0 " | awk '{print $1}' | head -1)
    if [ -z "$SID" ]; then
        SID=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$2==1000||$4==1000{print $1; exit}' 2>/dev/null)
    fi
    [ -z "$SID" ] && SID=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1; exit}')
    if [ -n "$SID" ]; then
        GRAPHICAL_USER=$(loginctl show-session "$SID" -p Name --value 2>/dev/null)
        SESSION_TYPE=$(loginctl show-session "$SID" -p Type --value 2>/dev/null)
    fi
}

GRAPHICAL_USER="${SUDO_USER:-$USER}"
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
detect_session
[ -n "$GRAPHICAL_USER" ] || GRAPHICAL_USER="$(logname 2>/dev/null || echo "")"
GRAPHICAL_UID=$(id -u "$GRAPHICAL_USER" 2>/dev/null || echo "1000")
# Session bus for the graphical user (needed for gsettings/gdbus)
if [ -n "$GRAPHICAL_UID" ] && [ -S "/run/user/$GRAPHICAL_UID/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$GRAPHICAL_UID/bus"
fi
# Helper: run as the graphical user (only via sudo if we are not that user/root)
as_user() {
    if [ "$(id -u)" -eq "$GRAPHICAL_UID" ]; then
        "$@"
    else
        sudo -u "$GRAPHICAL_USER" "$@"
    fi
}

echo "╔══════════════════════════════════════════════════════╗"
echo "║       ZENBOOK DUO - POST-INSTALL HEALTH CHECK       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Usuario gráfico: ${GRAPHICAL_USER:-(no detectado)}  Sesión: ${SESSION_TYPE:-?}"
echo ""

# 1. Services
echo "📦 SERVICIOS"
echo "────────────"
for svc in zenbook-duo zenbook-thermal zenbook-light-monitor zenbook-adaptive-brightness brightness-sync zenbook-auto-display zenbook-config battery-limit zenbook-nightlight mic-boost zenbook-bt-keyboard; do
    status=$(systemctl is-active ${svc}.service 2>/dev/null)
    enabled=$(systemctl is-enabled ${svc}.service 2>/dev/null)
    if [ "$status" = "active" ] && [ "$enabled" = "enabled" ]; then
        echo "  ✅ $svc (active + enabled)"
    elif [ "$status" = "active" ]; then
        echo "  ⚠️  $svc active but not enabled"
        WARNINGS=$((WARNINGS + 1))
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
DRM_CARD=""
for card in /sys/class/drm/card*/; do
    if [ -f "${card}eDP-1/status" ]; then
        DRM_CARD=$(basename "$card")
        break
    fi
done
DRM_CARD="${DRM_CARD:-card1}"
if [ -f "/sys/class/drm/${DRM_CARD}-eDP-1/status" ]; then
    echo "  ✅ eDP-1: $(cat "/sys/class/drm/${DRM_CARD}-eDP-1/status")"
else
    echo "  ❌ eDP-1 not found"
    ERRORS=$((ERRORS + 1))
fi
if [ -f "/sys/class/drm/${DRM_CARD}-eDP-2/status" ]; then
    echo "  ✅ eDP-2: $(cat "/sys/class/drm/${DRM_CARD}-eDP-2/status")"
else
    echo "  ⚠️  eDP-2 not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 5. USB Power Management (autosuspend)
echo "🔌 USB POWER MANAGEMENT"
echo "──────────────────────"
for dev in /sys/bus/usb/devices/*/idVendor; do
    vid=$(cat "$dev" 2>/dev/null)
    pid=$(cat "${dev%/idVendor}/idProduct" 2>/dev/null)
    case "$vid:$pid" in
        8087:0033|0b05:1b2c)
            auto=$(cat "${dev%/idVendor}/power/autosuspend" 2>/dev/null)
            if [ "$auto" = "-1" ]; then
                echo "  ✅ $vid:$pid autosuspend=$auto (disabled, correct)"
            else
                echo "  ❌ $vid:$pid autosuspend=$auto (expected -1)"
                ERRORS=$((ERRORS + 1))
            fi
            ;;
    esac
done
echo ""

# 6. Fan
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
    echo "  ⚠️  Fan sensor not found (may need reboot)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 7. Battery
echo "🔋 BATERÍA"
echo "──────────"
BAT_LIMIT=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
BAT_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
if [ -n "$BAT_LIMIT" ]; then
    if [ "$BAT_LIMIT" = "80" ]; then
        echo "  ✅ Charge limit: ${BAT_LIMIT}%"
    else
        echo "  ⚠️  Charge limit: ${BAT_LIMIT}% (expected 80)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ❌ Charge limit not set"
    ERRORS=$((ERRORS + 1))
fi
echo "  📊 Current level: ${BAT_LEVEL}%"
echo ""

# 8. Night Light (Wayland/GSettings)
echo "🌙 NIGHT LIGHT"
echo "──────────────"
if [ -n "$GRAPHICAL_USER" ]; then
    NL=$(as_user gsettings get org.gnome.settings-daemon.plugins.color night-light-enabled 2>/dev/null)
    if [ "$NL" = "true" ]; then
        echo "  ✅ Night light enabled"
    else
        echo "  ⚠️  Night light: $NL (expected true; uses redshift on X11)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ⚠️  No graphical user detected, cannot check night light"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 9. Microphone boost (PipeWire)
echo "🎤 MIC BOOST"
echo "────────────"
if [ -n "$GRAPHICAL_USER" ]; then
    MIC_VOL=$(as_user env XDG_RUNTIME_DIR=/run/user/$GRAPHICAL_UID wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
    if [ -n "$MIC_VOL" ]; then
        echo "  ✅ Mic volume: $MIC_VOL"
    else
        echo "  ⚠️  Cannot read mic volume (PipeWire not ready?)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ⚠️  No graphical user detected, cannot check mic boost"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 10. Touch Mapping (Wayland/Mutter)
echo "📱 TOUCH MAPPING"
echo "────────────────"
TOP_DEV=""
BOT_DEV=""
for d in /sys/class/input/input*/name; do
    name=$(cat "$d" 2>/dev/null)
    case "$name" in
        "ELAN9009:00 04F3:425A") TOP_DEV="$name";;
        "ELAN9008:00 04F3:425B") BOT_DEV="$name";;
    esac
done
if [ -n "$TOP_DEV" ] && [ -n "$BOT_DEV" ]; then
    echo "  ✅ Touch controllers detected"
    echo "     Top: $TOP_DEV"
    echo "     Bottom: $BOT_DEV"
else
    echo "  ⚠️  Touch controllers not found (top/bottom)"
    WARNINGS=$((WARNINGS + 1))
fi
if [ -n "$GRAPHICAL_USER" ]; then
    if as_user gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState >/dev/null 2>&1; then
        echo "  ✅ Mutter display config reachable (touch remap available)"
    else
        echo "  ⚠️  Mutter display config not reachable (touch remap via 'duo')"
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo ""

# 11. Audio (module may need reboot)
echo "🔊 AUDIO"
echo "────────"
if [ -d /sys/module/snd_hda_intel ]; then
    if pgrep -x pipewire >/dev/null 2>&1; then
        echo "  ✅ PipeWire active, audio module loaded"
    else
        echo "  ⚠️  Audio module loaded but PipeWire not running"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ⚠️  Audio module not loaded yet (requires reboot)"
    WARNINGS=$((WARNINGS + 1))
    REBOOT_PENDING=1
fi
echo ""

# 12. WiFi (module may need reboot)
echo "📶 WIFI"
echo "───────"
if [ -d /sys/module/iwlwifi ]; then
    echo "  ✅ WiFi module loaded"
else
    echo "  ⚠️  WiFi module not loaded yet (requires reboot)"
    WARNINGS=$((WARNINGS + 1))
    REBOOT_PENDING=1
fi
echo ""

# 13. Thermal / CPU temp
echo "🌡️  THERMAL"
echo "──────────"
TEMP=""
for tz in /sys/class/thermal/thermal_zone*/type; do
    if [ "$(cat "$tz" 2>/dev/null)" = "x86_pkg_temp" ]; then
        TEMP=$(cat "${tz%/*}/temp" 2>/dev/null)
        break
    fi
done
PROFILE=$(cat /sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/profile 2>/dev/null)
if [ -n "$TEMP" ]; then
    echo "  ✅ CPU temp: $((TEMP/1000))°C"
else
    echo "  ❌ Cannot read CPU temp"
    ERRORS=$((ERRORS + 1))
fi
echo "  📊 Profile: $PROFILE"
echo ""

# 14. Updates
echo "🔒 ACTUALIZACIONES"
echo "──────────────────"
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
[ -n "$UPDATES" ] || UPDATES="0"
if [ "$UPDATES" = "0" ]; then
    echo "  ✅ System up to date"
else
    echo "  ⚠️  $UPDATES paquete(s) pendientes"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════"
if [ $REBOOT_PENDING -eq 1 ]; then
    echo "  ℹ️  Algunos módulos requieren REINICIO para cargarse"
fi
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "  ✅ ALL CHECKS PASSED"
elif [ $ERRORS -eq 0 ]; then
    echo "  ⚠️  PASSED with $WARNINGS warning(s)"
else
    echo "  ❌ FAILED: $ERRORS error(s), $WARNINGS warning(s)"
fi
echo "════════════════════════════════════════════════════════"
[ $ERRORS -gt 0 ]