#!/bin/bash

# Try GNOME Shell DBus to toggle display
# This uses gjs to call GNOME Shell's display management

gjs -e "
const { Gio, Shell } = imports.gi;

try {
    // Get displays
    const display = global.display;
    const monitors = display.get_monitors();
    
    print('Monitors found: ' + monitors.length);
    
    monitors.forEach((m, i) => {
        print(i + ': ' + m.get_model() + ' - ' + m.get_connector());
    });
} catch (e) {
    print('Error: ' + e.message);
}
" 2>&1