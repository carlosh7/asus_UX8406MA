#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Thermal Monitor v3
# Calibrated for Intel Core Ultra 9 185H + ASUS UX8406MA
# Profiles: quiet (silent) → balanced (normal) → performance (max cooling)
# ============================================================================

LOG_FILE="/var/log/zenbook-thermal.log"
CHECK_INTERVAL=3
MAX_LOG_LINES=2000

# --- Calibrated Thresholds ---------------------------------------------------
# Intel Core Ultra 9 185H thermal behavior:
#   Idle:       40-55°C
#   Light use:  55-70°C
#   Moderate:   70-85°C
#   Heavy:      85-100°C (throttling starts ~100°C)

# Transition UP (heating):
PERF_TEMP=75000     # 75°C → performance (aggressive cooling before throttle)
BAL_TEMP=60000      # 60°C → balanced (moderate cooling)

# Transition DOWN (cooling) with hysteresis:
# Must drop below threshold MINUS hysteresis to transition down
HYSTERESIS=5000     # 5°C hysteresis to prevent oscillation

# Zone dead band: don't change profile if temp is within ±3°C of threshold
DEADBAND=3000       # 3°C dead band

MIN_CHANGE_INTERVAL=30  # Min 30s between profile changes

# Current state
CURRENT_PROFILE="balanced"
LAST_PROFILE_CHANGE=0
LAST_TEMP=0

# --- Dynamic Path Resolution ------------------------------------------------

resolve_cpu_zone() {
    for zone in /sys/class/thermal/thermal_zone*/type; do
        if [ "$(cat "$zone" 2>/dev/null)" = "x86_pkg_temp" ]; then
            echo "$(dirname "$zone")/temp"
            return
        fi
    done
    for zone in /sys/class/thermal/thermal_zone*/type; do
        if [ "$(cat "$zone" 2>/dev/null)" = "TCPU" ]; then
            echo "$(dirname "$zone")/temp"
            return
        fi
    done
    echo ""
}

resolve_fan_path() {
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

# Determine target profile based on temperature and current state
get_target_profile() {
    local temp="$1"
    local current="$2"

    case "$current" in
        quiet)
            # Currently quiet: switch up if getting hot
            if [ "$temp" -ge "$BAL_TEMP" ]; then
                echo "balanced"
            elif [ "$temp" -ge "$PERF_TEMP" ]; then
                echo "performance"
            else
                echo "quiet"
            fi
            ;;
        balanced)
            # Currently balanced: switch up if hot, down if cool enough
            if [ "$temp" -ge "$PERF_TEMP" ]; then
                echo "performance"
            elif [ "$temp" -lt "$((BAL_TEMP - HYSTERESIS))" ]; then
                echo "quiet"
            else
                echo "balanced"
            fi
            ;;
        performance)
            # Currently performance: only switch down if significantly cooler
            if [ "$temp" -lt "$((PERF_TEMP - HYSTERESIS))" ]; then
                echo "balanced"
            else
                echo "performance"
            fi
            ;;
        *)
            echo "balanced"
            ;;
    esac
}

set_profile() {
    local new_profile="$1"
    local now=$(date +%s)

    # Rate limit
    local elapsed=$((now - LAST_PROFILE_CHANGE))
    if [ "$elapsed" -lt "$MIN_CHANGE_INTERVAL" ]; then
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

echo "Zenbook Duo Thermal Monitor v3 started"
echo "  CPU zone: $CPU_ZONE"
echo "  Fan: $FAN_SPEED"
echo "  Platform profile: $PLATFORM_PROFILE"
echo "  Thresholds: quiet<$(($BAL_TEMP/1000))°C balanced<$(($PERF_TEMP/1000))°C performance>=$(($PERF_TEMP/1000))°C"
echo "  Hysteresis: $(($HYSTERESIS/1000))°C | Dead band: $(($DEADBAND/1000))°C"
echo ""

CURRENT_PROFILE=$(get_current_profile)
COUNTER=0

while true; do
    TEMP=$(get_cpu_temp)
    FAN=$(get_fan_speed)

    if [ "$TEMP" -eq 0 ]; then
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # Determine target profile
    TARGET=$(get_target_profile "$TEMP" "$CURRENT_PROFILE")

    # Apply dead band: don't change if temp is within dead band of last change
    temp_diff=$((TEMP - LAST_TEMP))
    if [ "$temp_diff" -lt 0 ]; then temp_diff=$((-temp_diff)); fi

    if [ "$TARGET" != "$CURRENT_PROFILE" ] && [ "$temp_diff" -gt "$DEADBAND" ]; then
        set_profile "$TARGET"
        LAST_TEMP=$TEMP
    fi

    # Log every 10th check (~30s) + rotate
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Temp: $(($TEMP/1000))°C | Fan: ${FAN} RPM | Profile: $(get_current_profile)" >> "$LOG_FILE"
        rotate_log
    fi

    sleep "$CHECK_INTERVAL"
done
