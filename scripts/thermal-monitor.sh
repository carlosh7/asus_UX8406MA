#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Thermal Monitor v4 (Calibrated)
# Calibrated with real stress test data for Intel Core Ultra 9 185H
# ============================================================================
#
# STRESS TEST RESULTS (30s @ 100% CPU, 22 cores):
# ┌──────────┬───────────┬──────────────┬──────────────┐
# │ Profile  │ Idle Temp │ Stress Temp  │ Fan Range    │
# ├──────────┼───────────┼──────────────┼──────────────┤
# │ quiet    │ 64-91°C   │ 95-97°C      │ 2900-4900    │
# │ balanced │ 65-76°C   │ 95-97°C      │ 3400-5100    │
# │ perform. │ 63-65°C   │ 99-101°C*    │ 3600-7900    │
# └──────────┴───────────┴──────────────┴──────────────┘
# * = thermal throttling
#
# CALIBRATION TARGETS:
# - quiet:     Keep below 70°C idle, below 80°C light load
# - balanced:  Keep below 85°C moderate load
# - performance: Maximum cooling (allow up to 95°C before throttle)
#
# ============================================================================

LOG_FILE="/var/log/zenbook-thermal.log"
CHECK_INTERVAL=3
MAX_LOG_LINES=2000

# --- Calibrated Thresholds (based on real stress tests) ----------------------
#
# TRANSITION UP (heating):
PERF_TEMP=82000     # 82°C → performance (before throttle at ~100°C)
BAL_TEMP=68000      # 68°C → balanced (moderate load begins)
#
# TRANSITION DOWN (cooling with hysteresis):
# Must drop below threshold MINUS hysteresis to transition down
HYSTERESIS=5000     # 5°C hysteresis
#
# DEAD BAND: don't change if temp changed less than this
DEADBAND=3000       # 3°C dead band
#
# MINIMUM TIME BETWEEN CHANGES
MIN_CHANGE_INTERVAL=30  # 30 seconds

# --- State -------------------------------------------------------------------

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

get_target_profile() {
    local temp="$1"
    local current="$2"

    case "$current" in
        quiet)
            if [ "$temp" -ge "$BAL_TEMP" ]; then
                echo "balanced"
            elif [ "$temp" -ge "$PERF_TEMP" ]; then
                echo "performance"
            else
                echo "quiet"
            fi
            ;;
        balanced)
            if [ "$temp" -ge "$PERF_TEMP" ]; then
                echo "performance"
            elif [ "$temp" -lt "$((BAL_TEMP - HYSTERESIS))" ]; then
                echo "quiet"
            else
                echo "balanced"
            fi
            ;;
        performance)
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

echo "Zenbook Duo Thermal Monitor v4 (Calibrated)"
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

    TARGET=$(get_target_profile "$TEMP" "$CURRENT_PROFILE")

    temp_diff=$((TEMP - LAST_TEMP))
    if [ "$temp_diff" -lt 0 ]; then temp_diff=$((-temp_diff)); fi

    if [ "$TARGET" != "$CURRENT_PROFILE" ] && [ "$temp_diff" -gt "$DEADBAND" ]; then
        set_profile "$TARGET"
        LAST_TEMP=$TEMP
    fi

    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Temp: $(($TEMP/1000))°C | Fan: ${FAN} RPM | Profile: $(get_current_profile)" >> "$LOG_FILE"
        rotate_log
    fi

    sleep "$CHECK_INTERVAL"
done
