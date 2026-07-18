#!/usr/bin/env python3
import dbus
import sys

def set_config(mode):
    bus = dbus.SessionBus()
    obj = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
    iface = dbus.Interface(obj, 'org.gnome.Mutter.DisplayConfig')
    serial, monitors, logical_monitors, properties = iface.GetCurrentState()
    
    connector_to_mode = {}
    for m in monitors:
        connector = m[0][0]
        current_mode = None
        for mode_info in m[1]:
            if 'is-current' in mode_info[5] and mode_info[5]['is-current']:
                current_mode = mode_info[0]
                break
        if not current_mode: current_mode = m[1][0][0]
        connector_to_mode[connector] = current_mode

    new_lms = []
    
    # Get eDP-1 info for dimensions
    edp1_lm = next((lm for lm in logical_monitors if any(m[0] == 'eDP-1' for m in lm[5])), None)
    edp2_lm = next((lm for lm in logical_monitors if any(m[0] == 'eDP-2' for m in lm[5])), None)
    
    # Get eDP-1 dimensions and scale from current config
    w1_log = 1648  # default logical width
    h1_log = 1030  # default logical height
    scale1 = dbus.Double(1.7475727796554565)  # default scale (2880/1648)
    
    if edp1_lm:
        x1, y1, s1, trans1, prim1, mons1, props1 = edp1_lm
        scale1 = s1  # Use the exact scale from current config
        edp1_info = next((m for m in monitors if m[0][0] == 'eDP-1'), None)
        if edp1_info:
            edp1_mode = next((m for m in edp1_info[1] if m[0] == connector_to_mode['eDP-1']), None)
            if edp1_mode:
                h1_log = int(round(edp1_mode[2] / float(scale1)))
                w1_log = int(round(edp1_mode[1] / float(scale1)))

    if mode == 'top':
        # Only eDP-1 (primary)
        new_lms.append(dbus.Struct((0, 0, scale1, 0, True,
            [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
            signature='iiduba(ssa{sv})'))

    elif mode == 'bottom':
        # Only eDP-2 (primary)
        edp2_scale = scale1
        if edp2_lm:
            edp2_scale = edp2_lm[2]
        new_lms.append(dbus.Struct((0, 0, edp2_scale, 0, True,
            [dbus.Struct(('eDP-2', connector_to_mode.get('eDP-2', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
            signature='iiduba(ssa{sv})'))

    elif mode == 'both':
        # eDP-1 (primary) + eDP-2 (below)
        new_lms.append(dbus.Struct((0, 0, scale1, 0, True,
            [dbus.Struct(('eDP-1', connector_to_mode.get('eDP-1', '2880x1800@120.000'), {}), signature='ssa{sv}')]),
            signature='iiduba(ssa{sv})'))
        edp2_mode_id = connector_to_mode.get('eDP-2', '2880x1800@120.000')
        new_lms.append(dbus.Struct((0, h1_log, scale1, 0, False,
            [dbus.Struct(('eDP-2', edp2_mode_id, {}), signature='ssa{sv}')]),
            signature='iiduba(ssa{sv})'))

    # External screens (preserve their current positions from logical_monitors)
    for lm in logical_monitors:
        if any(m[0] in ['eDP-1', 'eDP-2'] for m in lm[5]): continue
        new_mons = [dbus.Struct((m[0], connector_to_mode[m[0]], {}), signature='ssa{sv}') for m in lm[5]]
        # Use the existing position from logical_monitors
        new_lms.append(dbus.Struct((lm[0], lm[1], lm[2], lm[3], False, new_mons),
            signature='iiduba(ssa{sv})'))

    try:
        # Sort to ensure adjacency check passes
        new_lms.sort(key=lambda lm: (lm[0], lm[1]))
        
        # Method 1 (Temporary) - works for display switching WITHOUT confirmation dialog
        # Method 2 (Persistent) triggers GNOME display configuration dialog
        iface.ApplyMonitorsConfig(dbus.UInt32(serial), dbus.UInt32(1), new_lms, {})
        print("Success: %s" % mode)
    except Exception as e:
        print("Error: %s" % str(e))
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: %s <top|bottom|both>" % sys.argv[0])
        sys.exit(1)
    set_config(sys.argv[1])
