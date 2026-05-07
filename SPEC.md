# Zenbook Duo Linux - Specification Document

## 1. Project Overview

**Name**: zenbook-duo-linux
**Goal**: Complete hardware support for ASUS Zenbook Duo 2024 (UX8406MA) on Linux
**Target Distros**: Ubuntu 24.04+, Debian 12+

## 2. Hardware Analysis

### 2.1 Components to Support

| Component | ID | Driver Status | Notes |
|-----------|-----|---------------|-------|
| Intel Arc Graphics | 00:02.0 | i915 (OK) | Kernel 6.17+ |
| Audio | 00:1f.3 | sof-hda-dsp (OK) | |
| Keyboard USB | 0b05:1b2c | hid-generic (partial) | Fn not detected |
| Touchpad | same | hid-multitouch (OK) | |
| Bluetooth | 8087:0033 | btintel (OK) | |
| Webcam | 3277:0055 | uvcvideo (OK) | 5K capable |
| Top Display (eDP-1) | - | i915 (OK) | 3K 2880x1800 120Hz |
| Bottom Display (eDP-2) | - | i915 (OK) | Touch + stylus |

### 2.2 Keyboard Hotkeys (ES-Latino)

| Physical Key | Default Action | Linux Status | Fn+Key Action |
|--------------|----------------|--------------|---------------|
| F1 | Mute | ✅ works | F1 |
| F2 | Volume - | ✅ works | F2 |
| F3 | Volume + | ✅ works | F3 |
| F4 | KBD Light | ✅ works (bk.py) | F4 |
| F5 | Brightness - | ✅ works | F5 |
| F6 | Brightness + | ✅ works | F6 |
| F7 | Swap Screens | ✅ works | F7 |
| F9 | Mic Mute | ✅ works | F9 |
| F10 | Bluetooth | ❌ | F10 |
| F11 | Emojis | ❌ | F11 |
| F12 | ASUS SW | ❌ | F12 |
| Fn | - | ❌ not detected | - |

## 3. Architecture

### 3.1 Components

```
┌─────────────────────────────────────────────┐
│           zenbook-duo-linux                  │
├─────────────────────────────────────────────┤
│  CLI Tools (shell + python)                  │
│  - duo: display management, battery, etc.    │
│  - bk.py: keyboard backlight                 │
│  - hotkey_handler.py: F1-F12 mapping        │
├─────────────────────────────────────────────┤
│  Daemon (C)                                 │
│  - keyboard detection (USB/BT)              │
│  - auto display toggle                       │
│  - auto rotation monitoring                  │
├─────────────────────────────────────────────┤
│  Install System                              │
│  - install.sh: interactive installer         │
│  - uninstall.sh: clean removal               │
│  - .deb package (future)                    │
└─────────────────────────────────────────────┘
```

### 3.2 Module Responsibilities

**CLI (duo)**:
- Display configuration (top/bottom/both)
- Brightness sync
- Battery limit
- Keyboard backlight
- Tablet mapping
- Rotation commands

**Daemon (zbd)**:
- Monitor keyboard USB/BT connection
- Auto-toggle bottom screen
- Auto-enable/disable bluetooth
- Background hotkey handling (optional)

**Hotkey Handler**:
- Capture HID events from keyboard
- Map media keys to actions
- Handle F10 (Bluetooth), F11 (Emojis), F12 (ASUS)

## 4. Feature List

## 4. Feature List

### 4.1 Must Have (MVP) - ✅ COMPLETE

- [x] Display management (duo top/bottom/both)
- [x] Brightness sync between displays
- [x] Keyboard backlight control (0-3)
- [x] Battery limit (charge threshold)
- [x] Basic installation script

### 4.2 Should Have - ✅ COMPLETE

- [x] Auto-detach keyboard → show bottom screen (daemon)
- [x] Auto-attach keyboard → hide bottom screen (daemon)
- [x] Systemd services for auto-start
- [x] Tablet mode mapping

### 4.3 Nice to Have - ✅ COMPLETE

- [x] Systemd services for auto-start
- [x] Touch bottom screen toggle

## 5. Installation

### 5.1 Manual Install

```bash
git clone https://github.com/youruser/zenbook-duo-linux.git
cd zenbook-duo-linux
./install/install.sh
```

### 5.2 Dependencies

```
python3, python3-libusb
gnome-monitor-config / kscreen
inotify-tools
iio-sensor-proxy
usbutils
gcc, make (for daemon)
libusb-1.0-dev, libglib2.0-dev
```

## 6. Documentation Structure

```
README.md           - Quick start
INSTALL.md          - Detailed installation guide
USAGE.md            - Commands reference
TROUBLESHOOTING.md  - Common issues
HARDWARE.md         - Hardware specs
```

## 7. References

- alesya-h/zenbook-duo-2024-ux8406ma-linux (original scripts)
- valirc/zenbook-duo-2024-ux8406ma-daemon (C daemon)
- zakstam/zenbook-duo-linux (inspiration, Rust)
- fmstrat/zenbook-duo-linux (alternative)