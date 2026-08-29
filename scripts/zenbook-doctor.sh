#!/bin/bash
# ============================================================================
# Zenbook Doctor — auto-validación, monitoreo y auto-reparación
#
# Corre como servicio oneshot periódico (zenbook-doctor.timer, 15 min).
# Verifica el estado del stack Zenbook Duo y aplica reparaciones conocidas
# y seguras, dejando todo registrado en /var/log/zenbook-doctor.log y
# notificando a la sesión gráfica cuando repara algo.
#
# Reparaciones que aplica:
#   1. Servicios habilitados caídos          -> restart
#   2. Servicios deshabilitados por accidente -> enable --now
#   3. Permisos de configs del sistema        -> chmod 644 (logrotate H1)
#   4. Límite de carga de batería             -> re-aplicar del conf
#   5. Mapeo táctil ausente en dconf          -> touch-remap.sh
#   6. Bindings de hotkeys ausentes           -> setup-hotkeys.sh
#   7. fnlock-mode corrupto/ausente           -> recrear
#   8. Doctor timer deshabilitado             -> re-habilitarse
#
# Lo que NO hace: tocar hardware no verificado, reinstalar paquetes,
# ni "arreglar" cosas sin evidencia en el log.
# ============================================================================

set -u

CONF_DIR="/etc/zenbook-duo"
LOG_FILE="/var/log/zenbook-doctor.log"
REPAIRS=0

log_msg() { echo "[$(date '+%F %T')] $1" >> "$LOG_FILE" 2>/dev/null; }
repair()  { REPAIRS=$((REPAIRS + 1)); log_msg "REPARA: $1"; }

# --- Sesión gráfica (para dconf/gsettings/notify-send) ----------------------
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

run_as_gui() {  # run_as_gui <comando...> — ejecuta como usuario de sesión
    local u uid
    u=$(gui_user) || return 1
    uid=$(id -u "$u")
    sudo -u "$u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        XDG_RUNTIME_DIR="/run/user/$uid" "$@"
}

notify_gui() {
    run_as_gui notify-send -t 4000 -a 'Zenbook Doctor' "$1" 2>/dev/null || true
}

# --- 1. Servicios activos y habilitados -------------------------------------
MANAGED_UNITS="zenbook-duo brightness-sync zenbook-light-monitor zenbook-thermal \
zenbook-adaptive-brightness zenbook-config battery-limit zenbook-nightlight \
mic-boost zenbook-bt-keyboard zenbook-suspend-backlight"

for u in $MANAGED_UNITS; do
    en=$(systemctl is-enabled "$u.service" 2>/dev/null || true)
    st=$(systemctl is-active "$u.service" 2>/dev/null || true)
    if [ "$en" != "enabled" ]; then
        systemctl enable --now "$u.service" 2>/dev/null && repair "$u deshabilitado -> enable --now"
        continue
    fi
    if [ "$st" = "failed" ] || [ "$st" = "inactive" ]; then
        if systemctl restart "$u.service" 2>/dev/null; then
            repair "$u estaba $st -> reiniciado"
        else
            log_msg "ERROR: $u no pudo reiniciarse (revisar journal)"
        fi
    fi
done

# El propio timer del doctor
if [ "$(systemctl is-enabled zenbook-doctor.timer 2>/dev/null)" != "enabled" ]; then
    systemctl enable --now zenbook-doctor.timer 2>/dev/null && repair "doctor timer re-habilitado"
fi

# --- 2. Permisos de configs del sistema (logrotate rechaza 0664 — H1) -------
SYSTEM_CONFIGS="/etc/logrotate.d/zenbook-duo.conf /etc/modprobe.d/xe-gpu-optimize.conf \
/etc/sysctl.d/99-performance.conf /etc/tlp.d/01-zenbook.conf \
/etc/systemd/system/zenbook-*.service /etc/systemd/system/brightness-sync.service \
/etc/systemd/system/battery-limit.service /etc/systemd/system/mic-boost.service"
for f in $SYSTEM_CONFIGS; do
    [ -f "$f" ] || continue
    perms=$(stat -c %a "$f" 2>/dev/null) || continue
    if [ "$perms" != "644" ]; then
        chmod 644 "$f" && repair "chmod 644 $f (era $perms)"
    fi
done

# --- 3. Límite de carga de batería ------------------------------------------
limit=$(awk -F= '$1=="battery_limit"{print $2}' "$CONF_DIR/zenbook-duo.conf" 2>/dev/null)
limit=${limit:-80}
case "$limit" in ''|*[!0-9]*) limit=80 ;; esac
[ "$limit" -gt 100 ] && limit=100
[ "$limit" -lt 20 ] && limit=20
for b in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [ -f "$b" ] || continue
    cur=$(cat "$b" 2>/dev/null)
    if [ "$cur" != "$limit" ]; then
        echo "$limit" > "$b" 2>/dev/null && repair "batería $b: $cur -> $limit"
    fi
done

# --- 4/5. Mapeo táctil y hotkeys del usuario gráfico -------------------------
if u=$(gui_user); then
    uid=$(id -u "$u")
    touch_missing=0
    for vp in 04f3:425a 04f3:425b; do
        val=$(sudo -u "$u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              XDG_RUNTIME_DIR="/run/user/$uid" \
              dconf read "/org/gnome/desktop/peripherals/touchscreens/$vp/output" 2>/dev/null)
        [ -n "$val" ] || touch_missing=1
    done
    if [ "$touch_missing" -eq 1 ]; then
        if /usr/local/bin/touch-remap.sh >/dev/null 2>&1; then
            repair "mapeo táctil ausente en dconf -> touch-remap re-aplicado"
        else
            log_msg "ERROR: touch-remap.sh falló re-aplicando el mapeo"
        fi
    fi

    kb=$(sudo -u "$u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
         XDG_RUNTIME_DIR="/run/user/$uid" \
         gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null)
    case "$kb" in
        *custom0*) : ;;
        *)
            if sudo -u "$u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
                XDG_RUNTIME_DIR="/run/user/$uid" /usr/local/bin/setup-hotkeys.sh >/dev/null 2>&1; then
                repair "bindings de hotkeys ausentes -> setup-hotkeys re-aplicado"
            else
                log_msg "ERROR: setup-hotkeys.sh falló (¿sin bus de sesión?)"
            fi
            ;;
    esac
fi

# --- 6. ALS sensor -----------------------------------------------------------
ls /sys/bus/iio/devices/iio:device*/in_illuminance_raw >/dev/null 2>&1 || \
    log_msg "AVISO: sensor ALS no presente (adaptive-brightness y kb-backlight degradados)"

# --- 7. fnlock-mode ----------------------------------------------------------
if [ ! -s "$CONF_DIR/fnlock-mode" ]; then
    echo 0 > "$CONF_DIR/fnlock-mode" 2>/dev/null \
        && chmod 664 "$CONF_DIR/fnlock-mode" 2>/dev/null \
        && repair "fnlock-mode ausente/vacío -> recreado (multimedia)"
fi

# --- Resumen -----------------------------------------------------------------
if [ "$REPAIRS" -gt 0 ]; then
    log_msg "RESUMEN: $REPAIRS reparación(es) aplicada(s)"
    notify_gui "Zenbook Doctor: $REPAIRS reparación(es) aplicadas (ver journal)"
else
    log_msg "RESUMEN: todo OK"
fi
