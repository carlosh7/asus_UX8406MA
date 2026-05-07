# Zenbook Duo Linux

Hardware support for ASUS Zenbook Duo 2024 (UX8406MA) on Linux.

## Quick Install

```bash
git clone https://github.com/your-repo/zenbook-duo-linux.git
cd zenbook-duo-linux
cd install
./install.sh
```

## Requirements

- Ubuntu 24.04+ or Debian 12+
- GNOME (for display management)

## Usage

```bash
# Display management
duo top              # Top display only
duo bottom           # Bottom display only
duo both             # Both displays
duo toggle           # Toggle between top and both

# Brightness
duo sync-backlight   # Sync brightness once
duo watch-backlight  # Auto-sync brightness

# Keyboard backlight (0=off, 3=max)
duo set-kb-backlight 2

# Battery limit
duo bat-limit 80

# Auto rotation
duo watch-rotation

# Help
duo help
```

## Hardware Support

| Feature | Status |
|---------|--------|
| Dual 3K displays | ✅ |
| Touchscreen | ✅ |
| Keyboard backlight | ✅ |
| Brightness sync | ✅ |
| Battery limit | ✅ |
| Auto rotation | ✅ |
| Tablet mode | ✅ |
| Webcam | ✅ |
| Bluetooth | ✅ |
| Fn keys (F1-F12) | Partial |
| Auto keyboard detect | ✅ (daemon) |

## Documentation

See `docs/` folder for detailed guides:
- INSTALL.md - Full installation guide
- USAGE.md - Command reference
- TROUBLESHOOTING.md - Common issues

## License

BSD-2-Clause