#!/bin/bash
# Light monitor with inactivity detection

ALS_PATH=$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)
BK_SCRIPT="/usr/local/bin/bk.py"

last_level=-1
samples=()
SAMPLE_COUNT=3
SLEEP_INTERVAL=2
IDLE_TIMEOUT=30000 # 30 seconds in ms

get_idle_ms() {
    local idle=0
    # Try GNOME Mutter IdleMonitor first
    idle=$(dbus-send --print-reply --dest=org.gnome.Mutter.IdleMonitor /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null | grep uint64 | awk '{print $2}')
    if [ -z "$idle" ]; then
        idle=0
    fi
    echo "$idle"
}

is_monitor_on() {
    xset q 2>/dev/null | grep -q "Monitor is On"
    return $?
}

while true; do
    lux=$(cat "$ALS_PATH" 2>/dev/null)
    
    if [ -z "$lux" ]; then
        sleep "$SLEEP_INTERVAL"
        continue
    fi
    
    samples+=("$lux")
    if [ ${#samples[@]} -gt $SAMPLE_COUNT ]; then
        samples=("${samples[@]:1}")
    fi
    
    sum=0
    for s in "${samples[@]}"; do
        sum=$((sum + s))
    done
    avg=$((sum / ${#samples[@]}))
    
    # Thresholds (Raw values for UX8406MA)
    # > 5000: bright enough to turn off
    # > 1500: dim, level 1
    # > 500: dark, level 2
    # <= 500: pitch black, level 3
    if [ "$avg" -gt 5000 ]; then
        level=0
    elif [ "$avg" -gt 1500 ]; then
        level=1
    elif [ "$avg" -gt 500 ]; then
        level=2
    else
        level=3
    fi
    
    idle_ms=$(get_idle_ms)
    monitor_on=true
    if ! is_monitor_on; then
        monitor_on=false
    fi

    # Final decision
    final_level=$level
    
    # Turn off if idle or monitor off
    if [ "$idle_ms" -ge "$IDLE_TIMEOUT" ] || [ "$monitor_on" = false ]; then
        final_level=0
    fi
    
    if [ "$final_level" != "$last_level" ]; then
        sudo -n python3 "$BK_SCRIPT" "$final_level" 2>/dev/null
        echo "[$(date '+%H:%M:%S')] Lux: $avg | Idle: ${idle_ms}ms | Mon: $monitor_on -> Set level $final_level"
        last_level=$final_level
    fi
    
    sleep "$SLEEP_INTERVAL"
done