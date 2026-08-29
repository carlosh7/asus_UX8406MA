#!/bin/bash
# ============================================================================
# test-adaptive-brightness.sh — banco de pruebas de adaptive-brightness.sh v3
# Simula sysfs (ALS + brightness) en /tmp y valida el comportamiento sin
# tocar la pantalla real. Ejecutar como cualquier usuario.
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/adaptive-brightness.sh"

T=$(mktemp -d /tmp/zb-adaptive-test.XXXXXX)
ALS="$T/als"; BR="$T/br"; MAXF="$T/max"; LOG="$T/log"
echo 400 > "$MAXF"
echo 32  > "$BR"
echo 9053 > "$ALS"

# Determinismo para el test: sin EMA y sin espera mínima entre aplicaciones
export ZB_ALS_PATH="$ALS" ZB_BRIGHTNESS_PATH="$BR" ZB_MAX_BRIGHTNESS="$MAXF" ZB_LOG_FILE="$LOG"
export ZB_CHECK_INTERVAL=0.05 ZB_STABLE_READS=3 ZB_MANUAL_HOLD_SEC=2
export ZB_ADAPT_MIN_SEC=0 ZB_EMA_DEN=1

PASS=0; FAIL=0
assert() {
    local name="$1" expect="$2" got="$3"
    if [ "$expect" = "$got" ]; then
        PASS=$((PASS + 1)); echo "  PASS: $name (=$got)"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: $name (esperado $expect, obtenido $got)"
    fi
}
als_set() { echo "$1" > "$ALS"; }
br_ext()  { echo "$1" > "$BR"; }        # escritura "externa" (slider/teclas)
cycles()  { sleep "$(echo "$1 * 0.08" | bc -l)"; }
# assert_br: polling hasta 2s — el loop del script corre en otro proceso y
# el sleep fijo era fuente de flakes
assert_br() {
    local name="$1" expect="$2" got=""
    for _ in $(seq 1 20); do
        got=$(cat "$BR")
        [ "$got" = "$expect" ] && break
        sleep 0.1
    done
    assert "$name" "$expect" "$got"
}
cleanup() { kill "$PID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

echo "== Arranque =="
bash "$SCRIPT" >/dev/null 2>&1 &
PID=$!
cycles 6

echo "== S1: el ruido del sensor (±7%) NO cambia el brillo =="
for a in 9603 8778 9053 10153 9053 9603; do als_set "$a"; cycles 2; done
assert_br "S1 brillo intacto" "32"

echo "== S2: ajuste manual (slider a 400) se respeta =="
br_ext 400; cycles 8
assert_br "S2 manual adoptado" "400"
if grep -q "MANUAL: adoptado BR=400" "$LOG"; then assert "S2 log MANUAL" "si" "si"; else assert "S2 log MANUAL" "si" "no"; fi

echo "== S2b: fluctuación pequeña de luz NO rompe el manual (+32%) =="
als_set 12000; cycles 10
assert_br "S2b sigue en manual" "400"

echo "== S3: cambio REAL de luz (dark→interior alto) re-adapta =="
als_set 200000; cycles 12
assert_br "S3 re-adapta a curva" "276"

echo "== S4: timeout de HOLD reanuda CONSERVANDO el sesgo del usuario =="
br_ext 200; cycles 8
assert_br "S4 manual 200 adoptado" "200"
sleep 2.5; cycles 10
assert_br "S4 reanudado mantiene 200 (mismo ALS)" "200"
if grep -q "se conserva sesgo" "$LOG"; then assert "S4 log timeout+sesgo" "si" "si"; else assert "S4 log timeout+sesgo" "si" "no"; fi

echo "== S5: nueva luz fuerte re-adapta aplicando el sesgo =="
als_set 450000; cycles 12
assert_br "S5 curva(450k)+sesgo = 288" "288"

echo "== S6: pasos rápidos tipo F5/F6 (72→112→152) adoptan solo el final =="
br_ext 72;  cycles 2
br_ext 112; cycles 2
br_ext 152; cycles 10
assert_br "S6 adopta 152" "152"
cycles 10
assert_br "S6 sigue 152 (sin override)" "152"

echo "== S7: segundo ajuste manual durante modo manual actualiza el sesgo =="
als_set 200000; cycles 12          # vuelve al rango anterior: RESUME por Δ≥50%? |200k-450k|=250k ≥ 225k → sí re-adapta
br_ext 100; cycles 8
assert_br "S7 manual 100 adoptado" "100"
cycles 6
assert_br "S7 se mantiene 100" "100"

echo ""
echo "Resumen: $PASS PASS, $FAIL FAIL (tmp: $T)"
[ "$FAIL" -eq 0 ]
