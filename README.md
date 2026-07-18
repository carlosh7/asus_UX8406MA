# ASUS Zenbook Duo 2024 Linux Support — UX8406MA Driver & Utilities

**Complete Linux hardware support for ASUS Zenbook Duo 2024 (UX8406MA).** One-command install for Ubuntu, Arch, and Debian.

---

## What This Does

| Feature | Status |
|---------|--------|
| **Dual Screen Management** | Auto-switch bottom screen on keyboard attach/detach |
| **Touch Screen Mapping** | Both screens respond to touch correctly |
| **Keyboard Backlight** | Auto-adjusts based on ambient light |
| **Adaptive Brightness** | Screen brightness adapts to environment with manual override |
| **Thermal Control** | Auto fan profile based on CPU temperature |
| **Audio Profiles** | EasyEffects config for 4-speaker system |
| **WiFi Optimization** | iwlwifi config to prevent soft lockups |
| **Battery Protection** | Charge limit (default 80%) |

---

## Quick Install

```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git
cd asus_UX8406MA
sudo ./install/install.sh
```

Then restart your session.

---

## Supported Hardware

- **Model**: ASUS Zenbook Duo 2024 (UX8406MA)
- **Display**: Dual 3K OLED (2880x1800 @ 120Hz)
- **Touch**: Dual ELAN touch controllers
- **Audio**: Realtek ALC294 + CS35L41 smart amplifiers
- **WiFi**: Intel Meteor Lake CNVi
- **Keyboard**: USB + Bluetooth dual-mode

---

## Commands

```bash
# Display
duo top              # Top screen only
duo both             # Both screens
duo toggle           # Toggle mode
duo status           # Current state

# Brightness
duo set-kb-backlight 0-3    # Keyboard backlight
duo sync-backlight          # Sync screen brightness

# Battery
duo bat-limit 80            # Set charge limit

# Diagnostics
test_hardware.sh            # Full system test
audio-diagnose.sh           # Audio check
wifi-diagnose.sh            # WiFi check
```

---

## Supported Distributions

| Distro | Status |
|--------|--------|
| Ubuntu 24.04+ | ✅ Full support |
| Arch Linux | ✅ Full support |
| Debian 12+ | ✅ Full support |
| Pop!_OS, Mint | ✅ Should work |

---

## Documentation

- [Installation Guide](INSTALL.md)
- [Command Reference](USAGE.md)
- [Hardware Specs](SPEC.md)

---

## Credits

Based on work by:
- [alesya-h](https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux) — Original display scripts
- [valirc](https://github.com/valirc/zenbook-duo-2024-ux8406ma-daemon) — C daemon
- [zakstam](https://github.com/zakstam/zenbook-duo-linux) — Rust implementation
- [fmstrat](https://github.com/fmstrat/zenbook-duo-linux) — Alternative approach

---

## License

BSD-2-Clause
