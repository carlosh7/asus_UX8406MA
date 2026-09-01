#!/bin/bash
# ============================================================================
# test-resume-display.sh — banco de pruebas de resume-display.sh
# Simula lsusb, duo (con Mutter "terco" opcional) y touch-remap.
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/resume-display.sh"

T=$(mktemp -d /tmp/zb-resume-test.XXXXXX)
mkdir -p "$T/bin"

cat > "$T/bin/lsusb" <<EOF
#!/bin/bash
[ -f "$T/attached" ] && echo "Bus 003 Device 002: ID 0b05:1b2c ASUSTek"
exit 0
EOF
cat > "$T/bin/duo" <<EOF
#!/bin/bash
echo "\$*" >> "$T/duo-calls.txt"
if [ "\$1" = "status" ]; then
    if [ -f "$T/stubborn" ]; then echo "both"; else echo "\$(cat "$T/mode.txt" 2>/dev/null)"; fi
    exit 0
fi
[ -f "$T/stubborn" ] || echo "\$1" > "$T/mode.txt"
exit 0
EOF
cat > "$T/bin/touch-remap.sh" <<EOF
#!/bin/bash
touch "$T/touch-ran"
EOF
chmod +x "$T/bin/lsusb" "$T/bin/duo" "$T/bin/touch-remap.sh"

PASS=0; FAIL=0
assert() {
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS: $1 (= $3)"; else FAIL=$((FAIL+1)); echo "  FAIL: $1 (esperado $2, obtenido $3)"; fi
}

run_hook() {
    ( cd "$T/bin" && PATH="$T/bin:$PATH" ZB_DUO="$T/bin/duo" ZB_TOUCH="$T/bin/touch-remap.sh" \
      ZB_LOG_FILE="$T/log" bash "$SCRIPT" >/dev/null 2>&1 )
}

echo "== T1: teclado puesto, Mutter obediente -> top =="
touch "$T/attached"; rm -f "$T/stubborn" "$T/duo-calls.txt"; echo "both" > "$T/mode.txt"
run_hook
assert "T1 aplica top" "top" "$(grep -m1 '^top$' "$T/duo-calls.txt")"
grep -q "OK: modo=top" "$T/log" && assert "T1 verifica OK" "si" "si" || assert "T1 verifica OK" "si" "no"
[ -f "$T/touch-ran" ] && assert "T1 touch-remap" "si" "si" || assert "T1 touch-remap" "si" "no"

echo "== T2: teclado fuera -> both =="
rm -f "$T/attached" "$T/duo-calls.txt" "$T/touch-ran"; echo "top" > "$T/mode.txt"
run_hook
assert "T2 aplica both" "both" "$(grep -m1 '^both$' "$T/duo-calls.txt")"

echo "== T3: Mutter terco (siempre 'both' con teclado puesto) -> 6 intentos y ERROR =="
rm -f "$T/duo-calls.txt" "$T/log"; touch "$T/attached" "$T/stubborn"
run_hook; rc=$?
assert "T3 sale con error" "1" "$rc"
assert "T3 reintenta 6 veces (top)" "6" "$(grep -c '^top$' "$T/duo-calls.txt")"
grep -q "ERROR: no se logró" "$T/log" && assert "T3 log ERROR" "si" "si" || assert "T3 log ERROR" "si" "no"

echo ""
echo "Resumen: $PASS PASS, $FAIL FAIL (tmp: $T)"
[ "$FAIL" -eq 0 ]
