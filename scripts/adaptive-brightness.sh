#!/bin/bash
# ============================================================================
# Zenbook Duo - Adaptive Brightness Controller v3
# Custom brightness adaptation based on ALS sensor calibration
#
# v3 (2026-08-28): el ajuste MANUAL del usuario MANDA.
#   - v2 reiniciaba el contador de estabilidad cuando el brillo dejaba de
#     cambiar → el auto-ajuste sobreescribía el valor del usuario en el
#     ciclo siguiente (~5s). Además MAX_PAUSE_SEC=180 limitaba la pausa.
#   - Ahora: un cambio externo de brillo se adopta como preferencia (sesgo
#     respecto a la curva de calibración) y no se escribe de nuevo hasta que
#     la luz ambiental cambie de verdad (≥RESUME_PCT relativo o ≥RESUME_ABS_MIN)
#     o pase MANUAL_HOLD_SEC (reanudación conservando el sesgo del usuario).
#   - Modo activo con histéresis + EMA: solo re-aplica si ΔALS ≥ ADAPT_PCT
#     (relativo) y pasaron ADAPT_MIN_SEC → sin oscilación por ruido del sensor.
#
# Rutas sobre-escribibles por entorno (ZB_*) para testear con sysfs simulado.
# ============================================================================

ALS_PATH="${ZB_ALS_PATH:-$(ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw 2>/dev/null | head -n 1)}"
BRIGHTNESS_PATH="${ZB_BRIGHTNESS_PATH:-/sys/class/backlight/intel_backlight/brightness}"
MAX_BRIGHTNESS="${ZB_MAX_BRIGHTNESS:-/sys/class/backlight/intel_backlight/max_brightness}"
STATE_FILE="/tmp/zenbook-adaptive-brightness.state"
LOG_FILE="${ZB_LOG_FILE:-/var/log/zenbook-adaptive-brightness.log}"

CHECK_INTERVAL="${ZB_CHECK_INTERVAL:-5}"
STABLE_READS="${ZB_STABLE_READS:-3}"        # ciclos con el brillo externo estable para fijar el ajuste
MANUAL_HOLD_SEC="${ZB_MANUAL_HOLD_SEC:-3600}"  # el ajuste manual manda al menos 1h
RESUME_PCT="${ZB_RESUME_PCT:-50}"           # re-adaptar con ΔALS ≥ 50% relativo a la captura
RESUME_ABS_MIN="${ZB_RESUME_ABS_MIN:-40000}"   # ...o ≥ ~40 lux absolutos (lo que sea mayor)
ADAPT_PCT="${ZB_ADAPT_PCT:-25}"             # modo activo: re-aplicar solo con ΔALS ≥ 25% relativo
ADAPT_ABS_MIN="${ZB_ADAPT_ABS_MIN:-20000}"  # ...o ≥ ~20 lux absolutos
ADAPT_MIN_SEC="${ZB_ADAPT_MIN_SEC:-60}"     # ...y con ≥60s desde la última aplicación
EMA_DEN="${ZB_EMA_DEN:-4}"                  # suavizado: smooth=(smooth*(N-1)+als)/N

# Config opcional: /etc/zenbook-duo/adaptive-brightness.conf
[ -f /etc/zenbook-duo/adaptive-brightness.conf ] && \
    . /etc/zenbook-duo/adaptive-brightness.conf

# Calibration points (ALS raw -> brightness %)
CALIBRATION=(
    "272:6"        # Oscuro: 0.3 lux -> 6%
    "109545:39"    # Artificial: 109 lux -> 39%
    "122822:62"    # Escritorio: 122 lux -> 62%
    "540319:100"   # Ventana: 540 lux -> 100%
)

# State
EXPECTED_BR=0        # último valor escrito por nosotros (o adoptado del usuario)
LAST_APPLY_ALS=0     # ALS al aplicar por última vez (referencia de histéresis)
LAST_APPLY_TS=0
SMOOTH_ALS=0
BIAS=0               # brillo_usuario - curva(als_captura); se conserva en reanudación por timeout

MODE="auto"          # auto | manual
CAPTURED_BR=0        # valor externo en observación
CAPTURE_HITS=0
OVERRIDE_ALS=0
OVERRIDE_TS=0

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

get_ambient_light() {
    [ -f "$ALS_PATH" ] && cat "$ALS_PATH" 2>/dev/null || echo "0"
}

get_max_brightness() {
    cat "$MAX_BRIGHTNESS" 2>/dev/null || echo "400"
}

get_current_brightness() {
    cat "$BRIGHTNESS_PATH" 2>/dev/null || echo "0"
}

# Curva de calibración: ALS raw -> brillo absoluto (unidades del controlador)
cal_brightness() {
    local als="$1"
    local max_br
    max_br=$(get_max_brightness)

    local prev_als=0 prev_br=0 next_als=0 next_br=0
    for cal in "${CALIBRATION[@]}"; do
        local cal_als="${cal%%:*}"
        local cal_br="${cal##*:}"
        if [ "$als" -ge "$cal_als" ] 2>/dev/null; then
            prev_als=$cal_als
            prev_br=$cal_br
        elif [ "$next_als" -eq 0 ]; then
            next_als=$cal_als
            next_br=$cal_br
        fi
    done

    local pct
    if [ "$next_als" -gt 0 ] && [ "$prev_als" -gt 0 ]; then
        local range=$((next_als - prev_als))
        local pos=$((als - prev_als))
        local br_range=$((next_br - prev_br))
        if [ "$range" -gt 0 ]; then
            pct=$((prev_br + (pos * br_range / range)))
        else
            pct=$prev_br
        fi
    elif [ "$prev_als" -gt 0 ]; then
        pct=$prev_br
    else
        pct=$next_br
    fi
    echo $((pct * max_br / 100))
}

clamp_target() {
    local target="$1"
    local max
    max=$(get_max_brightness)
    if [ "$target" -lt 1 ] 2>/dev/null; then
        target=1
    elif [ "$target" -gt "$max" ] 2>/dev/null; then
        target=$max
    fi
    echo "$target"
}

set_brightness() {
    local target="$1"
    local current
    current=$(get_current_brightness)
    local max
    max=$(get_max_brightness)

    if [ "$target" -lt 1 ]; then
        target=1
    elif [ "$target" -gt "$max" ]; then
        target=$max
    fi

    local diff=$((target - current))
    if [ "$diff" -gt 5 ] || [ "$diff" -lt -5 ]; then
        echo "$target" > "$BRIGHTNESS_PATH"
        EXPECTED_BR=$target
        log_msg "Brightness: $current -> $target (ALS: $(get_ambient_light))"
    else
        EXPECTED_BR=$current
    fi
}

abs_diff() {
    local d=$(($1 - $2))
    [ "$d" -lt 0 ] && d=$((d * -1))
    echo "$d"
}

# Umbral de cambio significativo respecto a una referencia ALS
sig_threshold() {
    local rel=$(( $1 * ADAPT_PCT / 100 ))
    [ "$rel" -lt "$ADAPT_ABS_MIN" ] && rel=$ADAPT_ABS_MIN
    echo "$rel"
}

# Inicializar
EXPECTED_BR=$(get_current_brightness)
SMOOTH_ALS=$(get_ambient_light)
LAST_APPLY_ALS=$SMOOTH_ALS
LAST_APPLY_TS=$(date +%s)

log_msg "Adaptive brightness v3 started (initial: ALS=$SMOOTH_ALS, BR=$EXPECTED_BR)"
echo "Adaptive brightness controller v3 started"

while true; do
    sleep "$CHECK_INTERVAL"

    als=$(get_ambient_light)
    case "$als" in ''|*[!0-9]*) continue ;; esac

    # Suavizado EMA del sensor (rechaza jitter de lectura)
    SMOOTH_ALS=$(( (SMOOTH_ALS * (EMA_DEN - 1) + als) / EMA_DEN ))
    current_br=$(get_current_brightness)

    # --- Cambio externo en curso: brillo distinto a lo que escribimos -------
    if [ "$current_br" -ne "$EXPECTED_BR" ]; then
        if [ "$current_br" -eq "$CAPTURED_BR" ]; then
            CAPTURE_HITS=$((CAPTURE_HITS + 1))
        else
            CAPTURED_BR=$current_br
            CAPTURE_HITS=1
        fi
        # Valor estable tras STABLE_READS ciclos = decisión del usuario
        if [ "$CAPTURE_HITS" -ge "$STABLE_READS" ]; then
            cal_now=$(cal_brightness "$SMOOTH_ALS")
            BIAS=$(( CAPTURED_BR - cal_now ))
            OVERRIDE_ALS=$SMOOTH_ALS
            OVERRIDE_TS=$(date +%s)
            EXPECTED_BR=$CAPTURED_BR
            MODE="manual"
            CAPTURE_HITS=0
            log_msg "MANUAL: adoptado BR=$EXPECTED_BR (sesgo $BIAS vs curva $cal_now, ALS=$OVERRIDE_ALS)"
        fi
        continue
    fi
    CAPTURE_HITS=0

    # --- Modo manual: respetar al usuario hasta cambio real de luz ----------
    if [ "$MODE" = "manual" ]; then
        now=$(date +%s)
        elapsed=$((now - OVERRIDE_TS))
        d_als=$(abs_diff "$SMOOTH_ALS" "$OVERRIDE_ALS")
        rel=$(( OVERRIDE_ALS * RESUME_PCT / 100 ))
        [ "$rel" -lt "$RESUME_ABS_MIN" ] && rel=$RESUME_ABS_MIN
        if [ "$d_als" -ge "$rel" ]; then
            # Cambio real de contexto lumínico → re-adaptar desde la curva
            log_msg "RESUMED (ΔALS=$d_als ≥ $rel tras ${elapsed}s; sesgo descartado)"
            MODE="auto"
            BIAS=0
            LAST_APPLY_ALS=$SMOOTH_ALS
            LAST_APPLY_TS=$now
            set_brightness "$(clamp_target "$(cal_brightness "$SMOOTH_ALS")")"
        elif [ "$elapsed" -ge "$MANUAL_HOLD_SEC" ]; then
            # Reanudación conservadora: adapta alrededor de la preferencia del usuario
            log_msg "RESUMED (timeout ${elapsed}s; se conserva sesgo $BIAS)"
            MODE="auto"
            LAST_APPLY_ALS=$SMOOTH_ALS
            LAST_APPLY_TS=$now
            set_brightness "$(clamp_target "$(( $(cal_brightness "$SMOOTH_ALS") + BIAS ))")"
        fi
        continue
    fi

    # --- Modo auto: aplicar solo con cambio ambiental significativo ---------
    now=$(date +%s)
    d_apply=$(abs_diff "$SMOOTH_ALS" "$LAST_APPLY_ALS")
    thr=$(sig_threshold "$LAST_APPLY_ALS")
    if [ "$d_apply" -ge "$thr" ] && [ $((now - LAST_APPLY_TS)) -ge "$ADAPT_MIN_SEC" ]; then
        target=$(clamp_target "$(( $(cal_brightness "$SMOOTH_ALS") + BIAS ))")
        set_brightness "$target"
        LAST_APPLY_ALS=$SMOOTH_ALS
        LAST_APPLY_TS=$now
    fi
done
