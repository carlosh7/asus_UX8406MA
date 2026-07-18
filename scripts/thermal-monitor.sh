#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Thermal Monitor v2
# Dynamic path resolution, log rotation, fixed sudo
# ============================================================================

LOG_FILE="/var/log/zenbook-thermal.log"
CHECK_INTERVAL=3
ALERT_TEMP=70000    # 70°C - balanced
CRIT_TEMP=80000     # 80°C - performance
HYS_TEMP=65000      # 65°C - quiet (hysteresis)
MIN_CHANGE_INTERVAL=30  # Min 30s between profile changes
MAX_LOG_LINES=2000      # Max lines before rotation

# Current state
CURRENT_PROFILE="balanced"
LAST_PROFILE_CHANGE=0

# --- Dynamic Path Resolution ------------------------------------------------

resolve_cpu_zone() {
    # Find x86_pkg_temp (most accurate for CPU package temp)
    for zone in /sys/class/thermal/thermal_zone*/type; do
        if [ "$(cat "$zone" 2>/dev/null)" = "x86_pkg_temp" ]; then
            echo "$(dirname "$zone")/temp"
            return
        fi
    done
    # Fallback: try TCPU
    for zone in /sys/class/thermal/thermal_zone*/type; do
        if [ "$(cat "$zone" 2>/dev/null)" = "TCPU" ]; then
            echo "$(dirname "$zone")/temp"
            return
        fi
    done
    echo ""
}

resolve_fan_path() {
    # Find asus hwmon with fan input
    for hwmon in /sys/class/hwmon/hwmon*/name; do
        if [ "$(cat "$hwmon" 2>/dev/null)" = "asus" ]; then
            local dir=$(dirname "$hwmon")
            if [ -f "$dir/fan1_input" ]; then
                echo "$dir/fan1_input"
                return
            fi
        fi
    done
    echo ""
}

resolve_platform_profile() {
    for path in /sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-*/profile; do
        if [ -f "$path" ]; then
            echo "$path"
            return
        fi
    done
    echo ""
}

# Resolve paths at startup
CPU_ZONE=$(resolve_cpu_zone)
FAN_SPEED=$(resolve_fan_path)
PLATFORM_PROFILE=$(resolve_platform_profile)

# --- Functions ---------------------------------------------------------------

get_cpu_temp() {
    if [ -n "$CPU_ZONE" ] && [ -f "$CPU_ZONE" ]; then
        cat "$CPU_ZONE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_fan_speed() {
    if [ -n "$FAN_SPEED" ] && [ -f "$FAN_SPEED" ]; then
        cat "$FAN_SPEED" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_current_profile() {
    if [ -n "$PLATFORM_PROFILE" ] && [ -f "$PLATFORM_PROFILE" ]; then
        cat "$PLATFORM_PROFILE" 2>/dev/null || echo "balanced"
    else
        echo "balanced"
    fi
}

set_profile() {
    local new_profile="$1"
    local now=$(date +%s)

    # Rate limit
    local elapsed=$((now - LAST_PROFILE_CHANGE))
    if [ "$elapsed" -lt "$MIN_CHANGE_INTERVAL" ] && [ "$new_profile" != "$CURRENT_PROFILE" ]; then
        return 0
    fi

    if [ "$new_profile" != "$CURRENT_PROFILE" ]; then
        if [ -n "$PLATFORM_PROFILE" ] && [ -f "$PLATFORM_PROFILE" ]; then
            echo "$new_profile" | sudo -n tee "$PLATFORM_PROFILE" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile: $CURRENT_PROFILE -> $new_profile (CPU: $(($TEMP/1000))°C)" >> "$LOG_FILE"
                CURRENT_PROFILE="$new_profile"
                LAST_PROFILE_CHANGE=$now
            fi
        fi
    fi
}

rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local lines=$(wc -l < "$LOG_FILE")
        if [ "$lines" -gt "$MAX_LOG_LINES" ]; then
            tail -n $((MAX_LOG_LINES / 2)) "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated ($lines -> $((MAX_LOG_LINES / 2)) lines)" >> "$LOG_FILE"
        fi
    fi
}

# --- Main Loop ---------------------------------------------------------------

echo "Zenbook Duo Thermal Monitor v2 started"
echo "  CPU zone: $CPU_ZONE"
echo "  Fan: $FAN_SPEED"
echo "  Platform profile: $PLATFORM_PROFILE"
echo ""

CURRENT_PROFILE=$(get_current_profile)
COUNTER=0

while true; do
    TEMP=$(get_cpu_temp)
    FAN=$(get_fan_speed)
    PROFILE=$(get_current_profile)

    if [ "$TEMP" -eq 0 ]; then
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # Temperature-based profile selection
    if [ "$TEMP" -ge "$CRIT_TEMP" ]; then
        set_profile "performance"
    elif [ "$TEMP" -ge "$ALERT_TEMP" ]; then
        set_profile "balanced"
    elif [ "$TEMP" -lt "$HYS_TEMP" ] && [ "$CURRENT_PROFILE" != "quiet" ]; then
        set_profile "quiet"
    fi

    # Log every 10th check (~30s) + rotate
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Temp: $(($TEMP/1000))°C | Fan: ${FAN} RPM | Profile: $(get_current_profile)" >> "$LOG_FILE"
        rotate_log
    fi

    sleep "$CHECK_INTERVAL"
done
