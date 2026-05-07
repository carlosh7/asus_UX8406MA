#!/usr/bin/env gjs
imports.gi.versions.Gtk = '3.0';
const { GLib, Shell, Gdk } = imports.gi;

try {
    const display = global.display;
    const monitors = display.get_monitors();
    
    print('Monitors found: ' + monitors.length);
    
    for (let i = 0; i < monitors.length; i++) {
        const m = monitors.get(i);
        print(i + ': ' + m.get_model() + ' - ' + m.get_connector() + ' - is-enabled: ' + m.is_enabled());
    }
} catch (e) {
    print('Error: ' + e.message);
}