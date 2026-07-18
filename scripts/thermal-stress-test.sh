#!/bin/bash
# ============================================================================
# Thermal Stress Test - ASUS Zenbook Duo UX8406MA
# Tests CPU at different loads and records thermal behavior
# ============================================================================

LOG="/var/log/thermal-stress-test.log"
PLATFORM_PROFILE="/sys/devices/platform/asus-nb-wmi/platform-profile/platform-profile-0/profile"
CPU_ZONE="/sys/class/thermal/thermal_zone13/temp"  # x86_pkg_temp or TCPU

# Find correct thermal zone
for zone in /sys/class/thermal/thermal_zone*/type; do
    if [ "$(cat "$zone" 2>/dev/null)" = "x86_pkg_temp" ]; then
        CPU_ZONE="$(dirname "$zone")/temp"
        break
    fi
done

# Find fan
FAN_SPEED=""
for hwmon in /sys/class/hwmon/hwmon*/name; do
    if [ "$(cat "$hwmon" 2>/dev/null)" = "asus" ]; then
        dir=$(dirname "$hwmon")
        [ -f "$dir/fan1_input" ] && FAN_SPEED="$dir/fan1_input"
        break
    fi
done

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"
}

get_temp() { cat "$CPU_ZONE" 2>/dev/null || echo "0"; }
get_fan() { cat "$FAN_SPEED" 2>/dev/null || echo "0"; }
get_profile() { cat "$PLATFORM_PROFILE" 2>/dev/null || echo "unknown"; }

set_profile() {
    echo "$1" | sudo tee "$PLATFORM_PROFILE" >/dev/null 2>&1
}

record_state() {
    local temp=$(get_temp)
    local fan=$(get_fan)
    local profile=$(get_profile)
    local cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    log "  Temp: $((temp/1000))°C | Fan: ${fan} RPM | Profile: $profile | Freq: $((cpu_freq/1000))MHz"
}

# --- Test Configuration ---

CORES=$(nproc)
TEST_DURATION=30        # seconds per test
COOLDOWN_DURATION=30    # seconds between tests
CPU_LOAD_PERCENT=100    # stress-ng cpu load

echo "=============================================="
echo "  Thermal Stress Test - UX8406MA"
echo "=============================================="
echo ""
log "CPU cores: $CORES"
log "CPU zone: $CPU_ZONE"
log "Fan path: $FAN_SPEED"
log "Platform profile: $PLATFORM_PROFILE"
log "Test duration: ${TEST_DURATION}s per test"
log ""

# --- Baseline (idle) ---

log "=== BASELINE (IDLE) ==="
for i in $(seq 1 5); do
    record_state
    sleep 2
done
log ""

# --- Test each profile at idle ---

for profile in quiet balanced performance; do
    log "=== IDLE TEST: $profile ==="
    set_profile "$profile"
    sleep 5
    for i in $(seq 1 5); do
        record_state
        sleep 2
    done
    log ""
done

# --- Stress tests at each profile ---

for profile in quiet balanced performance; do
    log "=== STRESS TEST: $profile (${TEST_DURATION}s @ ${CPU_LOAD_PERCENT}% CPU) ==="
    set_profile "$profile"
    sleep 3

    # Record pre-stress state
    log "  Pre-stress:"
    record_state

    # Start stress-ng in background
    stress-ng --cpu "$CORES" --cpu-load "$CPU_LOAD_PERCENT" --timeout "${TEST_DURATION}s" --quiet &
    STRESS_PID=$!

    # Monitor during stress (every 3 seconds)
    START_TIME=$(date +%s)
    while [ $(($(date +%s) - START_TIME)) -lt "$TEST_DURATION" ]; do
        record_state
        sleep 3
    done

    # Wait for stress to finish
    wait $STRESS_PID 2>/dev/null

    # Record post-stress state
    log "  Post-stress:"
    record_state
    log ""

    # Cooldown
    log "  Cooldown ${COOLDOWN_DURATION}s..."
    sleep "$COOLDOWN_DURATION"
    log ""
done

# --- GPU test ---

log "=== GPU THERMAL TEST ==="
log "  Checking GPU temperature..."
for zone in /sys/class/thermal/thermal_zone*/type; do
    type=$(cat "$zone" 2>/dev/null)
    temp=$(cat "$(dirname "$zone")/temp" 2>/dev/null)
    case "$type" in
        *gpu*|*GPU*|*dgpu*|*intel*)
            log "  $type: $((temp/1000))°C"
            ;;
    esac
done
log ""

# --- Summary ---

log "=============================================="
log "  TEST COMPLETE"
log "=============================================="
log ""
log "Results saved to: $LOG"
log ""
log "Analyze with:"
log "  cat $LOG"
