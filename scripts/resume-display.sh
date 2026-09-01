#!/bin/bash
# ============================================================================
# resume-display.sh — Re-aplica el layout de pantallas al REANUDAR
#
# Bug (ronda 8, reporte usuario): tras suspender/cerrar tapa y retomar con el
# teclado puesto, Mutter re-enumera los paneles y reactiva eDP-2 (layout
# "ambas") — el cursor se pierde en la zona fantasma bajo el teclado. El
# daemon C no reacciona si el USB del teclado no cambia de estado en s2idle.
#
# Este hook corre en el resume (WantedBy=suspend.target, After=suspend.target)
# y re-aplica top/both según el teclado, VERIFICANDO contra Mutter (que puede
# restaurar su propio layout después de nosotros) hasta que el modo pegue.
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

duo_status() {
    "$DUO" status 2>/dev/null | tail -1
}

apply_layout() {
    if keyboard_attached; then
        want="top"
    else
        want="both"
    fi
    echo "$want"
}

want=$(apply_layout)
log_msg "resume: teclado=$(keyboard_attached && echo puesto || echo fuera) -> quiero $want"

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    "$DUO" "$want" >/dev/null 2>&1
    sleep "$WAIT"
    got=$(duo_status)
    if [ "$got" = "$want" ]; then
        log_msg "OK: modo=$got (intento $attempt)"
        "$TOUCH" >/dev/null 2>&1
        exit 0
    fi
    log_msg "intento $attempt: quiero $want, Mutter dice ${got:-n/d} — re-aplicando"
    attempt=$((attempt + 1))
done

log_msg "ERROR: no se logró asentar el modo $want tras $MAX_ATTEMPTS intentos (último: ${got:-n/d})"
exit 1
