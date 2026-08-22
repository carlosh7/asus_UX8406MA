#!/bin/bash
# ============================================================================
# Zenbook Duo - Touch Mapping Fix (v2)
# - Mapeo táctil EXPLÍCITO por dispositivo en dconf (sin ambigüedad de Mutter)
# - Re-aplica el layout para refrescar tras cambios de modo
# - Funciona invocado como usuario o como root (daemon): hace drop a la sesión
#
# Corrección ago-2026: los mapeos estaban invertidos (425b→eDP-1) y además
# nunca llegaban al dconf del usuario porque el daemon los ejecutaba como root.
# ============================================================================

TOP_TOUCH_VIDPID="04f3:425b"   # ELAN9008 — pantalla superior (verificado en hardware real)
BOT_TOUCH_VIDPID="04f3:425a"   # ELAN9009 — pantalla inferior (bajo teclado; el nº de modelo NO indica posición física)
TOP_OUT="eDP-1"
BOT_OUT="eDP-2"

# --- Sesión gráfica: resolver usuario y entorno D-Bus ----------------------
resolve_session() {
    SESSION_USER=""
    if [ "$(id -u)" -eq 0 ]; then
        SESSION_USER="${SUDO_USER:-}"
        if [ -z "$SESSION_USER" ]; then
            SESSION_USER=$(who | grep "(:0\|seat0)" | awk '{print $1}' | head -1)
        fi
        if [ -z "$SESSION_USER" ]; then
            SESSION_USER=$(loginctl list-sessions --no-legend 2>/dev/null | while read -r sid _rest; do
                local type=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
                local user=$(loginctl show-session "$sid" -p Name --value 2>/dev/null)
                [ "$type" = "wayland" ] || [ "$type" = "x11" ] && { echo "$user"; break; }
            done)
        fi
        [ -z "$SESSION_USER" ] && { echo "ERROR: sin sesión gráfica activa" >&2; exit 1; }
        UID_SESSION=$(id -u "$SESSION_USER")
    else
        SESSION_USER="$(id -un)"
        UID_SESSION=$(id -u)
    fi
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID_SESSION}/bus"
    export XDG_RUNTIME_DIR="/run/user/${UID_SESSION}"
}

# Re-ejecuta como el usuario de sesión si venimos de root (daemon/installer)
drop_to_session_user() {
    if [ "$(id -u)" -eq 0 ] && [ "$SESSION_USER" != "root" ]; then
        exec sudo -u "$SESSION_USER" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            "$0" "$@"
    fi
}

# --- Mapeo explícito touchscreen→output -------------------------------------
# Formato GVariant: array [fabricante, producto, serial, conector]
set_touch_mappings() {
    local panel_vendor='SDC' panel_product='0x419d' panel_serial='0x00000000'
    dconf write "/org/gnome/desktop/peripherals/touchscreens/${TOP_TOUCH_VIDPID}/output" \
        "['${panel_vendor}', '${panel_product}', '${panel_serial}', '${TOP_OUT}']" || return 1
    dconf write "/org/gnome/desktop/peripherals/touchscreens/${BOT_TOUCH_VIDPID}/output" \
        "['${panel_vendor}', '${panel_product}', '${panel_serial}', '${BOT_OUT}']" || return 1
}

# --- Modo actual según conectores activos -----------------------------------
get_mode() {
    python3 - << 'PYEOF'
import dbus
try:
    bus = dbus.SessionBus()
    obj = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
    iface = dbus.Interface(obj, 'org.gnome.Mutter.DisplayConfig')
    _serial, _monitors, logical_monitors, _props = iface.GetCurrentState()
    active = []
    for lm in logical_monitors:
        for m in lm[5]:
            active.append(str(m[0]))
    has1, has2 = 'eDP-1' in active, 'eDP-2' in active
    print('both' if has1 and has2 else 'top' if has1 else 'bottom' if has2 else 'none')
except Exception:
    print('none')
PYEOF
}

# --- Aplicar layout (refresca asociación táctil de Mutter) ------------------
apply_layout() {
    local mode="$1"
    python3 - "$mode" << 'PYEOF'
import dbus, sys

mode = sys.argv[1]
if mode not in ('top', 'both', 'bottom'):
    sys.exit(0)

bus = dbus.SessionBus()
obj = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
iface = dbus.Interface(obj, 'org.gnome.Mutter.DisplayConfig')
serial, monitors, logical_monitors, _properties = iface.GetCurrentState()

connector_to_mode = {}
for m in monitors:
    connector = str(m[0][0])
    current_mode = None
    for mode_info in m[1]:
        if isinstance(mode_info, dbus.Struct) and len(mode_info) >= 7:
            props = mode_info[6]
            if isinstance(props, dbus.Dictionary) and props.get('is-current'):
                current_mode = str(mode_info[0])
                break
    if not current_mode and len(m[1]) > 0:
        current_mode = str(m[1][0][0])
    connector_to_mode[connector] = current_mode

def monitor_state(connector):
    """(escala, alto_lógico) del logical monitor que contiene ese conector."""
    for lm in logical_monitors:
        if any(str(mm[0]) == connector for mm in lm[5]):
            scale = float(lm[2])
            info = next((m for m in monitors if str(m[0][0]) == connector), None)
            h_log = 1030
            if info:
                for mi in info[1]:
                    if isinstance(mi, dbus.Struct) and len(mi) >= 7:
                        props = mi[6]
                        if isinstance(props, dbus.Dictionary) and props.get('is-current'):
                            h_log = int(round(float(mi[2]) / max(scale, 0.01)))
                            break
            return scale, h_log
    return None, None

scale1, h1_log = monitor_state('eDP-1')
scale2, h2_log = monitor_state('eDP-2')
if scale1 is None: scale1 = 1.75
if scale2 is None: scale2 = scale1

new_lms = []
if mode == 'top':
    new_lms.append(dbus.Struct((0, 0, dbus.Double(scale1), 0, True,
        [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))
elif mode == 'bottom':
    new_lms.append(dbus.Struct((0, 0, dbus.Double(scale2), 0, True,
        [dbus.Struct(('eDP-2', connector_to_mode.get('eDP-2', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))
else:  # both: eDP-1 arriba, eDP-2 debajo
    new_lms.append(dbus.Struct((0, 0, dbus.Double(scale1), 0, True,
        [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))
    new_lms.append(dbus.Struct((0, h1_log, dbus.Double(scale2), 0, False,
        [dbus.Struct(('eDP-2', connector_to_mode.get('eDP-2', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))

new_lms.sort(key=lambda lm: (lm[0], lm[1]))
iface.ApplyMonitorsConfig(dbus.UInt32(serial), dbus.UInt32(1), new_lms, {})
print(f'Touch mapped + layout applied: {mode}')
PYEOF
}

# --- Main --------------------------------------------------------------------
resolve_session

# Si somos root (llamada desde daemon/installer), re-ejecutar como usuario de sesión
if [ "$(id -u)" -eq 0 ]; then
    drop_to_session_user "$@"
    exit $?
fi

set_touch_mappings || { echo "ERROR: no se pudo escribir mapeos dconf" >&2; exit 1; }
MODE=$(get_mode)
[ "$MODE" = "none" ] && { echo "Sin pantallas activas"; exit 0; }
apply_layout "$MODE"
