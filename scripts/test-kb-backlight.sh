#!/bin/bash
# ============================================================================
# test-kb-backlight.sh — banco de pruebas de kb-backlight-unified.sh v5
# Simula dbus-send (Mutter IdleMonitor) y bk.py para validar el idle-off
# sin tocar el hardware real. Ejecutar como cualquier usuario.
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/kb-backlight-unified.sh"

T=$(mktemp -d /tmp/zb-kbtest.XXXXXX)
mkdir -p "$T/bin"

# Stub de dbus-send: devuelve el idletime de $T/idle.txt (o falla si = FAIL)
cat > "$T/bin/dbus-send" <<EOF
#!/bin/bash
idle=\$(cat "$T/idle.txt" 2>/dev/null)
[ "\$idle" = "FAIL" ] && exit 1
echo "   uint64 \${idle:-0}"
exit 0
EOF
chmod +x "$T/bin/dbus-send"

# Stub de bk.py: registra los niveles aplicados
cat > "$T/bk.py" <<EOF
import sys
open("$T/bk-calls.txt","a").write(sys.argv[1]+"\n")
EOF

echo 60000 > "$T/idle.txt"     # inicia en idle
echo 1000  > "$T/als"          # oscuridad (umbral del sensor "als": <2500)
: > "$T/bk-calls.txt"

PASS=0; FAIL=0
assert() {
    local name="$1" expect="$2" got="$3"
    if [ "$expect" = "$got" ]; then
        PASS=$((PASS+1)); echo "  PASS: $name (= $got)"
    else
        FAIL=$((FAIL+1)); echo "  FAIL: $name (esperado $expect, obtenido $got)"
    fi
}
cleanup() { kill "$PID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

export PATH="$T/bin:$PATH"
export ZB_SKIP_CONF=1 ZB_BK_SCRIPT="$T/bk.py" ZB_STATE_FILE="$T/state" \
       ZB_TIMESTAMP_FILE="$T/ts" ZB_LOG_FILE="$T/log" ZB_ALS_PATH="$T/als" \
       ZB_ACTIVE=0.2 ZB_IDLE_POLL=0.2 INACTIVITY_TIMEOUT=30000

bash "$SCRIPT" >/dev/null 2>&1 &
PID=$!
sleep 1.5

echo "== S1: idle 60s en oscuridad -> luz OFF =="
grep -q "^0$" "$T/bk-calls.txt" && assert "S1 apaga en idle" "si" "si" || assert "S1 apaga en idle" "si" "no"
grep -q "Idle detected" "$T/log" && assert "S1 log Idle detected" "si" "si" || assert "S1 log Idle detected" "si" "no"
grep -q "Idle OK" "$T/log" && assert "S1 self-check OK" "si" "si" || assert "S1 self-check OK" "si" "no"

echo "== S2: vuelve la actividad -> luz ON (oscuridad) =="
echo 100 > "$T/idle.txt"
sleep 1.5
grep -q "^1$" "$T/bk-calls.txt" && assert "S2 enciende al volver" "si" "si" || assert "S2 enciende al volver" "si" "no"

echo "== S3: dbus muere -> AVISO visible, luz se queda por ALS (no cuelga) =="
echo FAIL > "$T/idle.txt"
sleep 1.5
grep -q "AVISO: sin bus" "$T/log" && assert "S3 AVISO registrado" "si" "si" || assert "S3 AVISO registrado" "si" "no"

echo "== S4: dbus se recupera -> idle-off vuelve a funcionar (auto-reparación) =="
echo 60000 > "$T/idle.txt"
sleep 1.5
last=$(tail -1 "$T/bk-calls.txt")
assert "S4 re-apaga en idle" "0" "$last"

echo ""
echo "Resumen: $PASS PASS, $FAIL FAIL (tmp: $T)"
[ "$FAIL" -eq 0 ]
