#!/bin/bash
# ============================================================================
# Zenbook Duo - Touch Mapping Fix
# Forces correct touch device mapping after display mode changes
# ============================================================================

TOP_TOUCH="ELAN9009:00 04F3:425A"  # Top screen touch controller
BOT_TOUCH="ELAN9008:00 04F3:425B"  # Bottom screen touch controller

# Get current display mode
get_mode() {
    python3 -c "
import dbus
bus = dbus.SessionBus()
obj = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
iface = dbus.Interface(obj, 'org.gnome.Mutter.DisplayConfig')
serial, monitors, logical_monitors, properties = iface.GetCurrentState()
active = []
for lm in logical_monitors:
    for m in lm[5]:
        active.append(str(m[0]))
if 'eDP-1' in active and 'eDP-2' in active:
    print('both')
elif 'eDP-1' in active:
    print('top')
elif 'eDP-2' in active:
    print('bottom')
else:
    print('none')
" 2>/dev/null
}

# Re-apply monitor config to force touch remapping
remap_touch() {
    local mode=$(get_mode)
    
    python3 -c "
import dbus, time

bus = dbus.SessionBus()
obj = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
iface = dbus.Interface(obj, 'org.gnome.Mutter.DisplayConfig')
serial, monitors, logical_monitors, properties = iface.GetCurrentState()

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
    if not current_mode: current_mode = str(m[1][0][0])
    connector_to_mode[connector] = current_mode

edp1_lm = next((lm for lm in logical_monitors if any(str(m[0]) == 'eDP-1' for m in lm[5])), None)
scale1 = dbus.Double(1.7475727796554565)
h1_log = 1030
if edp1_lm:
    scale1 = edp1_lm[2]
    edp1_info = next((m for m in monitors if str(m[0][0]) == 'eDP-1'), None)
    if edp1_info:
        for mode_info in edp1_info[1]:
            if isinstance(mode_info, dbus.Struct) and len(mode_info) >= 7:
                props = mode_info[6]
                if isinstance(props, dbus.Dictionary) and props.get('is-current'):
                    h1_log = int(round(float(mode_info[2]) / float(scale1)))
                    break

new_lms = []
mode = '$mode'

if mode == 'top':
    new_lms.append(dbus.Struct((0, 0, scale1, 0, True,
        [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))
elif mode == 'both':
    new_lms.append(dbus.Struct((0, 0, scale1, 0, True,
        [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))
    new_lms.append(dbus.Struct((0, h1_log, scale1, 0, False,
        [dbus.Struct(('eDP-2', connector_to_mode.get('eDP-2', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
        signature='iiduba(ssa{sv})'))

if new_lms:
    new_lms.sort(key=lambda lm: (lm[0], lm[1]))
    iface.ApplyMonitorsConfig(dbus.UInt32(serial), dbus.UInt32(1), new_lms, {})
    print('Touch remapped for %s mode' % mode)
" 2>/dev/null
}

# Main
remap_touch
