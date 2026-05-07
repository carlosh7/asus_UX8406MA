# Usage Reference

## Commands

### duo - Main Control Script

```bash
duo <command> [arguments]
```

#### Display Management

**duo top**
Show only top display (eDP-1).

```bash
duo top
```

**duo bottom**
Show only bottom display (eDP-2).

```bash
duo bottom
```

**duo both**
Show both displays (default for desktop mode).

```bash
duo both
```

**duo toggle**
Toggle between top-only and both displays.

```bash
duo toggle
```

**duo left-up**
Position screens vertically (bottom on left).

```bash
duo left-up
```

**duo right-up**
Position screens vertically (bottom on right).

```bash
duo right-up
```

**duo status**
Show current display configuration.

```bash
duo status
```

**duo watch-displays**
Auto-detect keyboard attachment and adjust displays.
Run in background: `duo watch-displays &`

```bash
duo watch-displays
```

#### Brightness

**duo sync-backlight**
Sync brightness from main display to bottom display (one-time).

```bash
duo sync-backlight
```

**duo watch-backlight**
Continuously sync brightness. Run in background:
```bash
duo watch-backlight &
```

#### Keyboard

**duo set-kb-backlight <0-3>**
Set keyboard backlight level.

```bash
duo set-kb-backlight 0  # Off
duo set-kb-backlight 1  # Low
duo set-kb-backlight 2  # Medium
duo set-kb-backlight 3  # High
```

#### Battery

**duo bat-limit [percentage]**
Set battery charge limit (default: 80%).

```bash
duo bat-limit          # Set to 80%
duo bat-limit 60       # Set to 60%
duo bat-limit 100     # Remove limit
```

#### Tablet Mode

**duo set-tablet-mapping**
Configure touchscreen mapping for tablet mode.

```bash
duo set-tablet-mapping
```

**duo toggle-bottom-touch**
Toggle touch input on bottom display.

```bash
duo toggle-bottom-touch
```

#### Rotation

**duo watch-rotation**
Auto-rotate displays based on accelerometer.
Requires iio-sensor-proxy.

```bash
duo watch-rotation &
```

#### System

**duo model**
Show detected model (3k or 1080p).

```bash
duo model
```

**duo help**
Show help message with all commands.

```bash
duo help
```

---

## bk.py - Keyboard Backlight

Control keyboard backlight directly.

```bash
python3 /usr/local/bin/bk.py <level>
```

Arguments:
- `0` - Off
- `1` - Low
- `2` - Medium  
- `3` - High

---

## Common Use Cases

### Startup Script
Add to ~/.bashrc or session startup:

```bash
# Sync brightness
duo watch-backlight &

# Auto-detach keyboard
duo watch-displays &
```

### Hotkeys Configuration

In GNOME Settings → Keyboard → Custom Shortcuts:

| Command | Suggested Shortcut |
|---------|-------------------|
| duo toggle | Super + P |
| duo set-kb-backlight 0 | Super + F4 |
| duo bat-limit 80 | Super + F10 |

---

## Systemd Services

### brightness-sync.service
Auto-starts brightness sync on login.

```bash
# Enable
systemctl --user enable brightness-sync.service

# Start
systemctl --user start brightness-sync.service

# Check status
systemctl --user status brightness-sync.service
```

### zenbook-duo.service (Daemon)
Full hardware daemon with auto keyboard detection.

```bash
# Enable on boot (system-wide, requires sudo)
sudo systemctl enable zenbook-duo.service

# Start now
sudo systemctl start zenbook-duo.service

# Check status
sudo systemctl status zenbook-duo.service

# View logs
sudo journalctl -u zenbook-duo.service -f
```

---

## zenbook-duo - Daemon

The daemon provides automatic hardware management:

```bash
zenbook-duo daemon      # Run as daemon
zenbook-duo status     # Show keyboard/display status
zenbook-duo display-both
zenbook-duo display-top
zenbook-duo brightness
zenbook-duo battery 80
```

Features:
- Auto-detect USB/Bluetooth keyboard
- Auto-toggle bottom screen on keyboard attach/detach
- Optional: auto-brightness sync
- Optional: auto-bluetooth toggle

Configuration: `/etc/zenbook-duo/zenbook-duo.conf`