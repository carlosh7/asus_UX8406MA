#!/bin/bash
# ============================================================================
# resume-display.sh — Re-aplica el layout de pantallas al REANUDAR
#
# Bug (ronda 8, reporte usuario): tras suspender/cerrar tapa y retomar con el
# teclado puesto, Mutter re-enumera los paneles y reactiva eDP-2 (layout
# "ambas") — el cursor se pierde en la zona fantasma bajo el teclado. El
# daemon C no reacciona si el USB del teclado no cambia de estado en s2idle.
#
# v2 (ronda 8): ejecuta duo/status/touch COMO EL USUARIO DE SESIÓN — `duo
# status` como root devuelve vacío (get-monitor-status no hace drop a la
# sesión), y por eso la verificación daba "n/d" en los resumes reales.
# Sin sesión gráfica (pantalla de login) no hay nada que re-aplicar.
# ============================================================================

DUO="${ZB_DUO:-/usr/local/bin/duo}"
TOUCH="${ZB_TOUCH:-/usr/local/bin/touch-remap.sh}"
LOG_FILE="${ZB_LOG_FILE:-/var/log/zenbook-resume-display.log}"
MAX_ATTEMPTS=6          # intentos de verificación (2s entre cada uno)
WAIT=2

keyboard_attached() {
    lsusb 2>/dev/null | grep -q "0b05:1b2c"
}

log_msg() { echo "[$(date '+%F %T')] $1" >> "$LOG_FILE" 2>/dev/null; }

gui_user() {
    local sid t
    while read -r sid _rest; do
        t=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
        if [ "$t" = "wayland" ] || [ "$t" = "x11" ]; then
            loginctl show-session "$sid" -p Name --value
            return 0
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
    return 1
}

GUI=$(gui_user)
if [ -z "$GUI" ]; then
    log_msg "sin sesión gráfica (¿login screen?) — nada que re-aplicar"
    exit 0
fi
GUI_UID=$(id -u "$GUI")

# Ejecutar como el usuario de sesión (status/apply necesitan su bus de Mutter)
run_gui() {
    sudo -u "$GUI" env \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$GUI_UID/bus" \
        XDG_RUNTIME_DIR="/run/user/$GUI_UID" \
        PATH="$PATH" \
        "$@"
}

want="both"
if keyboard_attached; then
    want="top"
fi
log_msg "resume: teclado=$(keyboard_attached && echo puesto || echo fuera) usuario=$GUI -> quiero $want"

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    run_gui "$DUO" "$want" >/dev/null 2>&1
    sleep "$WAIT"
    got=$(run_gui "$DUO" status 2>/dev/null | tail -1)
    if [ "$got" = "$want" ]; then
        log_msg "OK: modo=$got (intento $attempt)"
        run_gui "$TOUCH" >/dev/null 2>&1
        exit 0
    fi
    log_msg "intento $attempt: quiero $want, Mutter dice ${got:-n/d} — re-aplicando"
    attempt=$((attempt + 1))
done

log_msg "ERROR: no se logró asentar el modo $want tras $MAX_ATTEMPTS intentos (último: ${got:-n/d})"
exit 1
