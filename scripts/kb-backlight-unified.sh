#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Unified Keyboard Backlight Manager v5
# v5: detección de idle REPARADA — el bus de sesión se resuelve dinámicamente
#     (la unidad tenía %U → /run/user/0 en servicio de sistema: GetIdletime
#     fallaba siempre y la luz quedaba encendida con la pantalla apagada).
#     Self-check al arrancar + AVISO visible si el bus no responde.
# v4: Faster idle wake-up (1s polling when off, 3s when on)
# ============================================================================

BK_SCRIPT="${ZB_BK_SCRIPT:-/usr/local/bin/bk.py}"
STATE_FILE="${ZB_STATE_FILE:-/var/lib/zenbook-duo/kb-backlight.state}"
TIMESTAMP_FILE="${ZB_TIMESTAMP_FILE:-/var/lib/zenbook-duo/kb-backlight.timestamp}"
LOG_FILE="${ZB_LOG_FILE:-/var/log/zenbook-kb-backlight.log}"

# --- Configuration -----------------------------------------------------------

CHECK_INTERVAL_ACTIVE="${ZB_ACTIVE:-3}"     # Seconds between checks when backlight is ON
CHECK_INTERVAL_IDLE="${ZB_IDLE_POLL:-1}"    # Seconds between checks when backlight is OFF (fast wake-up)
INACTIVITY_TIMEOUT="${INACTIVITY_TIMEOUT:-30000}"  # 30 seconds idle -> turn off backlight (ms)
DEBOUNCE_SEC=10                             # Minimum seconds between level changes (when ON)
# Ronda 10: la tecla de ciclo manual (kb-light-cycle) escribe una marca; el
# auto-ajuste se pausa MANUAL_HOLD_SEC para no aplanar el nivel elegido
MANUAL_LOCK="${ZB_MANUAL_LOCK:-/var/lib/zenbook-duo/kb-backlight.manual}"
MANUAL_HOLD_SEC="${MANUAL_HOLD_SEC:-300}"

# Config opcional del usuario (sobreescribe lo anterior):
#   /etc/zenbook-duo/kb-backlight.conf
#   Ejemplo: INACTIVITY_TIMEOUT=60000  (60s antes de apagar la luz)
[ -z "${ZB_SKIP_CONF:-}" ] && [ -f /etc/zenbook-duo/kb-backlight.conf ] && \
    . /etc/zenbook-duo/kb-backlight.conf

# Light thresholds (raw ALS values, scale=0.001)
LIGHT_BRIGHT=2500     # >2500 raw -> level 0 (off, bright enough)

# --- Functions ---------------------------------------------------------------

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

# Resolve ALS path dynamically (find sensor named "als")
resolve_als_path() {
    local path=""
    for dev in /sys/bus/iio/devices/iio:device*/name; do
        if [ "$(cat "$dev" 2>/dev/null)" = "als" ]; then
            local dir=$(dirname "$dev")
            path="$dir/in_illuminance_raw"
            break
        fi
    done
    echo "$path"
}

# --- Bus de sesión del usuario gráfico ---------------------------------------
# En servicios de sistema systemd no hereda el bus y el especificador %U
# expande a 0 (root). Resolvemos el socket real probando candidatos (env,
# UID efectivo, resto de /run/user/*/bus) y cacheamos el que responda.
# NOTA: get_idle_ms setea IDLE_MS como global — NO llamarla dentro de $( ),
# el subshell perdería la caché del bus (bug del primer intento v5).
IDLE_BUS=""
IDLE_MS=0
IDLE_WARNED=0

_idle_query() {
    dbus-send --print-reply --dest=org.gnome.Mutter.IdleMonitor \
        /org/gnome/Mutter/IdleMonitor/Core \
        org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null | \
        grep uint64 | awk '{print $2}'
}

get_idle_ms() {
    local c idle
    if [ -n "$IDLE_BUS" ]; then
        idle=$(_idle_query)
        if [ -n "$idle" ]; then
            IDLE_MS=$idle
            return
        fi
        IDLE_BUS=""   # el bus cacheado murió: re-resolver ahora
    fi
    local -a candidates=()
    [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && candidates+=("$DBUS_SESSION_BUS_ADDRESS")
    candidates+=("unix:path=/run/user/$(id -u)/bus")
    local d
    for d in /run/user/*/bus; do
        [ -S "$d" ] && candidates+=("unix:path=$d")
    done
    for c in "${candidates[@]}"; do
        idle=$(DBUS_SESSION_BUS_ADDRESS="$c" _idle_query)
        if [ -n "$idle" ] && [ "$idle" -ge 0 ] 2>/dev/null; then
            IDLE_BUS=$c
            IDLE_MS=$idle
            IDLE_WARNED=0
            return
        fi
    done
    IDLE_MS=0
    if [ "$IDLE_WARNED" -eq 0 ]; then
        log_msg "AVISO: sin bus de sesión para Mutter IdleMonitor — idle-off INACTIVO"
        IDLE_WARNED=1
    fi
}

get_ambient_light() {
    if [ -n "$ALS_PATH" ] && [ -f "$ALS_PATH" ]; then
        cat "$ALS_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_light_level() {
    local lux="$1"
    if [ "$lux" -gt "$LIGHT_BRIGHT" ] 2>/dev/null; then
        echo "0"   # Bright -> off
    else
        echo "1"   # Any dark condition -> level 1 (fixed, no fluctuation)
    fi
}

# Debounce: only change if enough time passed since last change
debounce_ok() {
    local now=$(date +%s)
    local last_change=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "0")
    local elapsed=$((now - last_change))
    [ "$elapsed" -ge "$DEBOUNCE_SEC" ]
}

# Ronda 10: ¿el usuario acaba de ciclar la luz con la tecla? (kb-light-cycle)
manual_hold_active() {
    local ts=$(cat "$MANUAL_LOCK" 2>/dev/null || echo 0)
    local now=$(date +%s)
    [ "$((now - ts))" -ge 0 ] && [ "$((now - ts))" -lt "$MANUAL_HOLD_SEC" ]
}

set_keyboard_backlight() {
    local level="$1"
    local current_level=$(cat "$STATE_FILE" 2>/dev/null || echo "-1")

    if [ "$level" != "$current_level" ]; then
        # Debounce: skip if last change was < DEBOUNCE_SEC ago
        # Exception: allow turning OFF (level 0) or ON from idle immediately
        if [ "$level" != "0" ] && [ "$current_level" != "0" ] && ! debounce_ok; then
            return 0
        fi

        python3 "$BK_SCRIPT" "$level" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$level" > "$STATE_FILE"
            date +%s > "$TIMESTAMP_FILE"
            log_msg "Backlight: $current_level -> $level"
        fi
    fi
}

keyboard_is_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

# --- Main Loop ---------------------------------------------------------------

ALS_PATH="${ZB_ALS_PATH:-}"
[ -n "$ALS_PATH" ] || ALS_PATH=$(resolve_als_path)

# Self-check: si la detección de idle no funciona, la luz quedaría siempre
# encendida en oscuridad (bug ago-2026). Dejarlo registrado en el log.
get_idle_ms
if [ -n "$IDLE_BUS" ]; then
    log_msg "Starting v5 | ALS: $ALS_PATH | Timeout: ${INACTIVITY_TIMEOUT}ms | Poll: ${CHECK_INTERVAL_IDLE}s(off)/${CHECK_INTERVAL_ACTIVE}s(on) | Idle OK (bus=$IDLE_BUS, ${IDLE_MS}ms)"
else
    log_msg "Starting v5 | ALS: $ALS_PATH | AVISO: sin bus de sesión para Mutter IdleMonitor — idle-off INACTIVO"
fi
echo "2" > "$STATE_FILE"

PREV_IDLE_STATE="active"   # "active" or "idle"
MANUAL_NOTIFIED=0          # log del manual-hold emitido una sola vez

while true; do
    # 1. Keyboard attached?
    if ! keyboard_is_attached; then
        set_keyboard_backlight "0"
        PREV_IDLE_STATE="active"
        sleep "$CHECK_INTERVAL_IDLE"
        continue
    fi

    # 2. Check inactivity FIRST (before ALS)
    get_idle_ms
    idle_ms=$IDLE_MS

    if [ "$idle_ms" -ge "$INACTIVITY_TIMEOUT" ] 2>/dev/null; then
        # IDLE: turn off backlight, poll fast for wake-up
        if [ "$PREV_IDLE_STATE" != "idle" ]; then
            log_msg "Idle detected (${idle_ms}ms) -> OFF"
            PREV_IDLE_STATE="idle"
        fi
        set_keyboard_backlight "0"
        sleep "$CHECK_INTERVAL_IDLE"     # Fast polling when off
    else
        # ACTIVE: restore backlight (level 1 if dark, level 0 if bright)
        if [ "$PREV_IDLE_STATE" = "idle" ]; then
            log_msg "Activity detected (${idle_ms}ms) -> restoring"
            PREV_IDLE_STATE="active"
        fi

        # Ronda 10: tras un ciclo manual (tecla F4), respetar el nivel elegido
        # durante MANUAL_HOLD_SEC; el idle-off del bloque de arriba sigue vivo
        if manual_hold_active; then
            if [ "$MANUAL_NOTIFIED" -eq 0 ]; then
                log_msg "Manual hold activo (${MANUAL_HOLD_SEC}s) — auto-ajuste en pausa"
                MANUAL_NOTIFIED=1
            fi
            sleep "$CHECK_INTERVAL_ACTIVE"
            continue
        fi
        MANUAL_NOTIFIED=0

        lux=$(get_ambient_light)
        light_level=$(get_light_level "$lux")
        set_keyboard_backlight "$light_level"
        sleep "$CHECK_INTERVAL_ACTIVE"   # Normal polling when on
    fi
done
