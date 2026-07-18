#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Thermal Monitor
# Monitors CPU temperature and adjusts fan profile automatically
# ============================================================================

LOG_FILE="/var/log/zenbook-thermal.log"
CHECK_INTERVAL=3
ALERT_TEMP=70000    # 70°C - start using balanced (proactive cooling)
CRIT_TEMP=80000     # 80°C - use performance (aggressive cooling)
HYS_TEMP=65000      # 65°C - hysteresis (go back to quiet below this)
MIN_CHANGE_INTERVAL=30  # Minimum 30 seconds between profile changes

# Thermal zones (UX8406MA specific)
# Zone 12: x86_pkg_temp (CPU package - most accurate)
# Zone 10: TCPU (CPU core)
# Zone 0: acpitz (ACPI thermal zone)
CPU_ZONE="/sys/class/thermal/thermal_zone12/temp"
FAN_SPEED="/sys/class/hwmon/hwmon7/fan1_input"
PLATFORM_PROFILE="/sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/profile"

# Current state
CURRENT_PROFILE="balanced"
LAST_PROFILE_CHANGE=0

get_cpu_temp() {
    if [ -f "$CPU_ZONE" ]; then
        cat "$CPU_ZONE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_fan_speed() {
    if [ -f "$FAN_SPEED" ]; then
        cat "$FAN_SPEED" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_current_profile() {
    if [ -f "$PLATFORM_PROFILE" ]; then
        cat "$PLATFORM_PROFILE" 2>/dev/null || echo "balanced"
    else
        echo "balanced"
    fi
}

set_profile() {
    local new_profile="$1"
    local now=$(date +%s)
    
    # Don't change too frequently (minimum MIN_CHANGE_INTERVAL seconds between changes)
    local elapsed=$((now - LAST_PROFILE_CHANGE))
    if [ "$elapsed" -lt "$MIN_CHANGE_INTERVAL" ] && [ "$new_profile" != "$CURRENT_PROFILE" ]; then
        return 0
    fi
    
    if [ "$new_profile" != "$CURRENT_PROFILE" ]; then
        if [ -f "$PLATFORM_PROFILE" ]; then
            echo "$new_profile" | sudo tee "$PLATFORM_PROFILE" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile: $CURRENT_PROFILE -> $new_profile (CPU: $(($TEMP/1000))°C)" >> "$LOG_FILE"
                CURRENT_PROFILE="$new_profile"
                LAST_PROFILE_CHANGE=$now
            fi
        fi
    fi
}

log_status() {
    local temp="$1"
    local fan="$2"
    local profile="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Temp: $(($temp/1000))°C | Fan: ${fan} RPM | Profile: $profile" >> "$LOG_FILE"
}

# --- Main Loop ---------------------------------------------------------------

echo "Zenbook Duo Thermal Monitor started"
echo "  CPU zone: $CPU_ZONE"
echo "  Fan: $FAN_SPEED"
echo "  Platform profile: $PLATFORM_PROFILE"
echo "  Check interval: ${CHECK_INTERVAL}s"
echo ""

CURRENT_PROFILE=$(get_current_profile)

while true; do
    TEMP=$(get_cpu_temp)
    FAN=$(get_fan_speed)
    PROFILE=$(get_current_profile)
    
    if [ "$TEMP" -eq 0 ]; then
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Temperature-based profile selection
    # Proactive: start cooling BEFORE it gets too hot
    if [ "$TEMP" -ge "$CRIT_TEMP" ]; then
        # Hot (>=80°C): use performance (max fan)
        set_profile "performance"
    elif [ "$TEMP" -ge "$ALERT_TEMP" ]; then
        # Warm (>=70°C): use balanced (moderate fan)
        set_profile "balanced"
    elif [ "$TEMP" -lt "$HYS_TEMP" ] && [ "$CURRENT_PROFILE" != "quiet" ]; then
        # Cool (<65°C): use quiet (minimal fan)
        set_profile "quiet"
    fi
    
    # Log every 10th check (every ~50 seconds)
    COUNTER=${COUNTER:-0}
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        log_status "$TEMP" "$FAN" "$(get_current_profile)"
    fi
    
    sleep "$CHECK_INTERVAL"
done
