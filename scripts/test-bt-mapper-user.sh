#!/bin/bash
# ============================================================================
# test-bt-mapper-user.sh — resolución de usuario del mapper a prueba de utmp
#
# Bug (ronda 9, N3): utmp anotó la sesión con el UID numérico ("1000" en vez
# del nombre); find_session_user devolvía el número, getpwnam(<número>)
# fallaba siempre y el notify-send del OSD de brillo moría (28× la noche del
# incidente). El fix (_resolve_user) normaliza UID numérico → nombre real.
#
# Portable: usa el UID del usuario que ejecuta el test (sin hardcodes).
# Uso: ./test-bt-mapper-user.sh   (stub de who/loginctl por PATH, sin root)
# ============================================================================
set -u
cd "$(dirname "$0")" || exit 1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

MYUID=$(id -u)
MYNAME=$(id -un)

PYCODE='
import importlib.util
spec = importlib.util.spec_from_file_location("mapper", "bt-keyboard-mapper.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.find_session_user())
'

PASS=0; FAIL=0
check() { # nombre esperado obtenido
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1)); echo "PASS: $1"
    else
        FAIL=$((FAIL+1)); echo "FAIL: $1 (esperado='$2' obtenido='$3')"
    fi
}

# --- Caso 1: utmp con UID numérico (el caso real del 2026-10-29) ------------
cat > "$TMP/bin/who" <<EOF
#!/bin/bash
printf '%s     seat0        2026-10-29 23:31\n%s     tty2         2026-10-29 23:31\n' "$MYUID" "$MYUID"
EOF
cat > "$TMP/bin/loginctl" <<EOF
#!/bin/bash
if [ "\${1:-}" = "list-sessions" ]; then
    printf '1 %s %s -     2545 manager -    no -\n' "$MYUID" "$MYNAME"
    printf '3 %s %s seat0 6838 user    tty2 no -\n' "$MYUID" "$MYNAME"
elif [ "\${1:-}" = "show-session" ]; then
    echo "wayland"
fi
EOF
chmod +x "$TMP/bin/who" "$TMP/bin/loginctl"
got=$(env -u SUDO_USER PATH="$TMP/bin:/usr/bin:/bin" python3 -c "$PYCODE")
check "who-con-UID-numerico-devuelve-nombre" "$MYNAME" "$got"

# --- Caso 2: who con nombre válido → se acepta directo -----------------------
cat > "$TMP/bin/who" <<EOF
#!/bin/bash
printf '%s     seat0        2026-10-29 23:31\n' "$MYNAME"
EOF
chmod +x "$TMP/bin/who"
got=$(env -u SUDO_USER PATH="$TMP/bin:/usr/bin:/bin" python3 -c "$PYCODE")
check "who-con-nombre-valido" "$MYNAME" "$got"

# --- Caso 3: who con usuario inexistente → cae al fallback loginctl ----------
cat > "$TMP/bin/who" <<EOF
#!/bin/bash
printf 'fantasma seat0       2026-10-29 23:31\n'
EOF
chmod +x "$TMP/bin/who"
got=$(env -u SUDO_USER PATH="$TMP/bin:/usr/bin:/bin" python3 -c "$PYCODE")
check "who-invalido-cae-a-loginctl" "$MYNAME" "$got"

# --- Caso 4: _session_env tolera el UID como "nombre" (defensa) --------------
got=$(env -u SUDO_USER PATH="$TMP/bin:/usr/bin:/bin" MYUID="$MYUID" python3 -c '
import importlib.util, os
spec = importlib.util.spec_from_file_location("mapper", "bt-keyboard-mapper.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m._session_env(os.environ["MYUID"])["DBUS_SESSION_BUS_ADDRESS"])
')
check "session_env-tolera-UID" "unix:path=/run/user/$MYUID/bus" "$got"

# --- Caso 5: SUDO_USER numérico también se normaliza -------------------------
got=$(env SUDO_USER="$MYUID" PATH="$TMP/bin:/usr/bin:/bin" python3 -c "$PYCODE")
check "SUDO_USER-numerico" "$MYNAME" "$got"

echo "RESULTADO: $PASS PASS, $FAIL FAIL"
[ "$FAIL" -eq 0 ]
