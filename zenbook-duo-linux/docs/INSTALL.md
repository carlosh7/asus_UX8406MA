# Installation Guide

## Prerequisites

### System Requirements
- Ubuntu 24.04.1 LTS or newer
- Debian 12 (Bookworm) or newer
- GNOME Desktop Environment

### Required Packages
The installer will automatically install:
- `python3` - Python runtime
- `python3-libusb` - USB device access
- `gnome-monitor-config` - Display configuration
- `inotify-tools` - File monitoring
- `lm-sensors` - Hardware sensors
- `iio-sensor-proxy` - Accelerometer for rotation
- `usbutils` - USB device listing

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/your-repo/zenbook-duo-linux.git
cd zenbook-duo-linux
```

### 2. Run Installer

```bash
cd install
./install.sh
```

### 3. Log Out and Back In
Required for group membership changes (input group).

### 4. Test Installation

```bash
duo help
duo both
duo set-kb-backlight 2
```

## Manual Installation (Optional)

If you prefer manual installation:

```bash
# Create directories
sudo mkdir -p /opt/zenbook-duo /etc/zenbook-duo

# Copy scripts
sudo cp scripts/duo /usr/local/bin/
sudo cp scripts/bk.py /usr/local/bin/
sudo chmod +x /usr/local/bin/duo

# Install dependencies
sudo apt install python3 python3-libusb gnome-monitor-config inotify-tools iio-sensor-proxy
```

## Post-Installation

### Auto-start on Login

```bash
# For brightness sync
systemctl --user enable --now brightness-sync.service

# For display auto-management (run at session start)
duo watch-displays &
```

### Configuration Files

- `/etc/zenbook-duo/` - Configuration directory (future)
- `~/.config/systemd/user/` - User systemd services

## Uninstallation

```bash
sudo rm -f /usr/local/bin/duo /usr/local/bin/bk.py
sudo rm -rf /opt/zenbook-duo /etc/zenbook-duo
rm -rf ~/.config/systemd/user/brightness-sync.service
systemctl --user daemon-reload
```

## Troubleshooting

### "gnome-monitor-config not found"
Install manually:
```bash
sudo apt install gnome-monitor-config
```

### "Permission denied" errors
Make sure you logged out and back in after installation to apply group changes.

### Brightness not working
Check backlight path:
```bash
ls /sys/class/backlight/
```
Update the `backlight` variable in `scripts/duo` if different.

### Battery limit not working
Verify sysfs path:
```bash
ls /sys/class/power_supply/BAT0/
```