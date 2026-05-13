# Troubleshooting Guide

## Common Issues

### Installation

#### "Command not found: gnome-monitor-config"
**Problem**: Display management commands don't work.

**Solution**:
```bash
sudo apt update
sudo apt install gnome-monitor-config
# Or use Mutter's gdctl
which gdctl && gdctl list
```

#### "Permission denied" errors
**Problem**: Cannot write to brightness or battery files.

**Solution**:
1. Log out and back in (required for group changes)
2. Or run:
```bash
newgrp input
# Test
duo sync-backlight
```

---

### Display

#### "No displays found" or displays not toggling
**Problem**: `duo both` or `duo toggle` doesn't work.

**Diagnosis**:
```bash
# Check displays detected
gnome-monitor-config list

# Check systemd-logind
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') | grep -i display
```

**Solution**: Ensure you're on GNOME/Wayland. gnome-monitor-config only works on GNOME.

#### Bottom screen remains black
**Problem**: eDP-2 is detected but shows black screen.

**Solution**:
```bash
# Check if display is enabled
cat /sys/class/drm/card1-eDP-2/enabled

# Try xrandr alternative
xrandr --output eDP-2 --auto
xrandr --output eDP-2 --below eDP-1
```

#### "Apply" button is greyed out/disabled
**Problem**: GNOME Settings doesn't let you apply display changes.

**Causes**: 
1. The `zenbook-duo` daemon is conflicting with manual changes.
2. Monitor overlap (e.g., HDMI-1 at 0x0 while eDP-1 is also at 0x0).
3. X11 limitation with mixed scales.

**Solution**:
1. Stop the daemon: `sudo systemctl stop zenbook-duo`
2. Correct the position manually: `xrandr --output HDMI-1 --auto --right-of eDP-1`
3. Save the layout: `duo save-ext`
4. Switch to **Wayland** for a better multi-monitor experience.

#### No per-monitor scale option
**Problem**: Only one global scale is available for all monitors.

**Solution**: This is a limitation of GNOME on X11. Switch to a **Wayland** session to enable independent scaling per monitor.
Alternatively, use `xrandr --output <monitor> --scale 1.25x1.25` and then `duo save-ext`.

---

### Brightness

#### "No such file or directory" - backlight path
**Problem**: Brightness sync fails.

**Diagnosis**:
```bash
ls /sys/class/backlight/
```

**Solution**: Update path in `scripts/duo` line ~21:
```bash
backlight="card1-eDP-2-backlight"  # adjust to match your path
```

Common paths:
- `intel_backlight`
- `acpi_video0`
- `card0-eDP-1-backlight`

#### Brightness sync not working
**Problem**: `duo sync-backlight` does nothing.

**Solution**:
```bash
# Check permissions
ls -la /sys/class/backlight/*/brightness

# Manually test
sudo tee /sys/class/backlight/intel_backlight/brightness > /dev/null <<< 500
```

---

### Keyboard

#### Keyboard not detected
**Problem**: `keyboard-is-attached` always returns false.

**Diagnosis**:
```bash
lsusb | grep 0b05
# Should show: "0b05:1b2c"
```

**Solution**:
```bash
# Install usbutils
sudo apt install usbutils

# Check USB subsystem
ls /dev/bus/usb/
```

#### "Device not found" - keyboard backlight
**Problem**: `bk.py` can't find keyboard.

**Diagnosis**:
```bash
lsusb | grep 0b05:1b2c
python3 -c "import usb.core; print(usb.core.find(idVendor=0x0b05))"
```

**Solution**:
1. Ensure keyboard is connected via USB (not Bluetooth only)
2. Run with sudo:
```bash
sudo python3 /usr/local/bin/bk.py 2
```

---

### Battery

#### "No such file or directory" - battery limit
**Problem**: Battery limit doesn't work.

**Diagnosis**:
```bash
ls /sys/class/power_supply/
ls /sys/class/power_supply/BAT0/
```

**Solution**:
1. Check if your battery supports charging limits:
```bash
ls /sys/class/power_supply/BAT0/ | grep charge_control
```

2. If not supported, this is a hardware/firmware limitation.

---

### Daemon

#### "zenbook-duo: command not found"
**Problem**: Daemon not installed.

**Solution**:
```bash
cd zenbook-duo-linux/daemon
make
sudo make install
```

#### Daemon not starting
**Problem**: Service fails to start.

**Diagnosis**:
```bash
sudo journalctl -u zenbook-duo.service -n 50
sudo systemctl status zenbook-duo.service
```

**Common causes**:
- Missing duo in PATH - fix: `sudo cp /opt/zenbook-duo/duo /usr/local/bin/`
- gnome-monitor-config not available
- Python3 not installed

---

### Bluetooth

#### Keyboard not pairing via Bluetooth
**Problem**: Can't connect keyboard over BT.

**Solution**:
```bash
# Enable bluetooth
rfkill unblock bluetooth
bluetoothctl

# In bluetoothctl:
> power on
> agent on
> default-agent
> scan on
# Wait for "ASUS Zenbook Duo Keyboard"
> pair XX:XX:XX:XX:XX:XX
> connect XX:XX:XX:XX:XX:XX
> trust XX:XX:XX:XX:XX:XX
```

---

### Fn Keys

#### Fn key not detected
**Problem**: Pressing Fn alone doesn't do anything.

**Status**: This is a known limitation. The keyboard sends Fn events via HID but Linux doesn't capture them.

**Workaround**: Use media keys directly (F1=Volume, F5=Brightness, etc.)

**Alternative**: Use zakstam/zenbook-duo-linux daemon which has full Fn support.

---

## Diagnostic Commands

### System Info
```bash
# Kernel version
uname -a

# Graphics
lspci | grep -i vga

# USB devices
lsusb

# Input devices
cat /proc/bus/input/devices | grep -A 3 Keyboard

# Backlight
ls /sys/class/backlight/

# Battery
ls /sys/class/power_supply/BAT0/
```

### Test Scripts
```bash
# Test display
duo status
duo both

# Test brightness
duo sync-backlight

# Test keyboard
python3 /usr/local/bin/bk.py 2

# Test battery
duo bat-limit 80
```

---

## Getting Help

1. Check logs:
```bash
sudo journalctl -xe
dmesg | grep -i "error\|fail\|asus"
```

2. Test each component individually
3. Open issue at: https://github.com/your-repo/zenbook-duo-linux/issues