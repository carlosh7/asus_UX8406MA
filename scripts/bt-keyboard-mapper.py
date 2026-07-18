#!/usr/bin/env python3
"""
Zenbook Duo - Bluetooth Keyboard Keycode Mapper
Maps ABS_MISC events from Bluetooth keyboard to standard keycodes
"""

import subprocess
import sys
import os
import time

# ABS_MISC value -> function mapping
KEYCODE_MAP = {
    16: "F5",      # Brightness Down
    32: "F6",      # Brightness Up
    124: "F9",     # Mic Mute
    199: "F4",     # Keyboard Backlight
}

# Function commands
FUNCTION_MAP = {
    "F4": "/usr/local/bin/kb-light-cycle.sh",
    "F5": "gdbus call --session --dest org.gnome.settings-daemon.plugins.media-keys --object-path /org/gnome/settings-daemon/plugins/media-keys --method org.gnome.settings-daemon.plugins.media-keys.Decrease",
    "F6": "gdbus call --session --dest org.gnome.settings-daemon.plugins.media-keys --object-path /org/gnome/settings-daemon/plugins/media-keys --method org.gnome.settings-daemon.plugins.media-keys.Increase",
    "F9": "gdbus call --session --dest org.gnome.settings-daemon.plugins.media-keys --object-path /org/gnome/settings-daemon/plugins/media-keys --method org.gnome.settings-daemon.plugins.media-keys.MicMute",
}

def get_bt_keyboard_abs_device():
    """Find the Bluetooth keyboard ABS_MISC device"""
    # Known ABS_MISC device for ASUS Zenbook Duo Keyboard
    # Based on testing: event16 has ABS_MISC capability
    abs_devices = ["/dev/input/event16", "/dev/input/event17"]
    
    for dev in abs_devices:
        if os.path.exists(dev):
            path = f"/sys/class/input/{os.path.basename(dev)}/device/name"
            try:
                with open(path, 'r') as f:
                    name = f.read().strip()
                    if "ASUS Zenbook Duo Keyboard" in name:
                        return dev
            except:
                pass
    return None

def monitor_events():
    """Monitor ABS_MISC events from Bluetooth keyboard"""
    device = get_bt_keyboard_abs_device()
    if not device:
        print("Bluetooth keyboard ABS device not found")
        return
    
    print(f"Monitoring {device} for ABS_MISC events...")
    print("Press F4, F5, F6, F9 on Bluetooth keyboard")
    print("")
    
    try:
        proc = subprocess.Popen(
            ["sudo", "evtest", device],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            
            if "ABS_MISC" in line and "value" in line:
                # Extract value
                parts = line.split("value")
                if len(parts) > 1:
                    try:
                        value = int(parts[1].strip())
                        if value > 0 and value in KEYCODE_MAP:
                            key = KEYCODE_MAP[value]
                            print(f"  ABS_MISC {value} -> {key}")
                            
                            # Execute function
                            if key in FUNCTION_MAP:
                                cmd = FUNCTION_MAP[key]
                                subprocess.run(cmd, shell=True)
                                print(f"    Executed: {cmd}")
                    except ValueError:
                        pass
    except KeyboardInterrupt:
        print("\nStopped monitoring")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    monitor_events()
