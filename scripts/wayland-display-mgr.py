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
    edp1_lm = next((lm for lm in logical_monitors if any(m[0] == 'eDP-1' for m in lm[5])), None)
    if not edp1_lm: sys.exit(1)
    
    x1, y1, scale1, trans1, prim1, mons1, props1 = edp1_lm
    edp1_info = next(m for m in monitors if m[0][0] == 'eDP-1')
    edp1_mode = next(m for m in edp1_info[1] if m[0] == connector_to_mode['eDP-1'])
    h1_log = int(round(edp1_mode[2] / scale1))
    w1_log = int(round(edp1_mode[1] / scale1))

    # Construct logical monitors list
    # eDP-1
    new_lms.append(dbus.Struct((0, 0, scale1, trans1, True, 
        [dbus.Struct(('eDP-1', connector_to_mode['eDP-1'], {}), signature='ssa{sv}')]), signature='iiduba(ssa{sv})'))

    if mode == 'both':
        edp2_mode_id = connector_to_mode.get('eDP-2', '2880x1800@120.000')
        new_lms.append(dbus.Struct((0, h1_log, scale1, 0, False, 
            [dbus.Struct(('eDP-2', edp2_mode_id, {}), signature='ssa{sv}')]), signature='iiduba(ssa{sv})'))

    # External screens
    x_ptr = w1_log
    for lm in logical_monitors:
        if any(m[0] in ['eDP-1', 'eDP-2'] for m in lm[5]): continue
        new_mons = [dbus.Struct((m[0], connector_to_mode[m[0]], {}), signature='ssa{sv}') for m in lm[5]]
        new_lms.append(dbus.Struct((x_ptr, 0, lm[2], lm[3], False, new_mons), signature='iiduba(ssa{sv})'))
        m_info = next(m for m in monitors if m[0][0] == lm[5][0][0])
        m_mode = next(m for m in m_info[1] if m[0] == connector_to_mode[lm[5][0][0]])
        x_ptr += int(round(m_mode[1] / lm[2]))

    try:
        # Sort to ensure adjacency check passes
        new_lms.sort(key=lambda lm: (lm[0], lm[1]))
        
        # Method 2 (Persistent) should be the most reliable
        iface.ApplyMonitorsConfig(dbus.UInt32(serial), dbus.UInt32(2), new_lms, {})
        print(f"Success: {mode}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(1)
    set_config(sys.argv[1])
