# Hardware Specifications

## ASUS Zenbook Duo 2024 (UX8406MA)

### System

| Component | Details |
|-----------|---------|
| CPU | Intel Core Ultra 7 (Meteor Lake) |
| GPU | Intel Arc Graphics (integrated) |
| RAM | 16GB LPDDR5 |
| Storage | 1TB NVMe SSD |
| OS Tested | Ubuntu 24.04.1 LTS |

---

## Hardware Components

### Graphics

```
00:02.0 VGA compatible controller: Intel Corporation Meteor Lake-P [Intel Arc Graphics] (rev 08)
```

- **Driver**: i915 (kernel module)
- **Status**: ✅ Working
- **Notes**: Kernel 6.17+ recommended for best support

### Audio

```
00:1f.3 Multimedia audio controller: Intel Corporation Meteor Lake-P HD Audio Controller (rev 20)
```

- **Driver**: sof-hda-dsp
- **Status**: ✅ Working

---

## Displays

### Top Display (eDP-1)
- **Type**: OLED
- **Resolution**: 2880 x 1800 (3K)
- **Refresh Rate**: 120Hz
- **Touch**: Yes (10-point)
- **Stylus**: ASUS Pen 2.0 supported

### Bottom Display (eDP-2)
- **Type**: IPS
- **Resolution**: 2880 x 1800 (3K)
- **Refresh Rate**: 120Hz
- **Touch**: Yes (10-point)
- **Stylus**: ASUS Pen 2.0 supported

**Device Paths**:
- `/sys/class/drm/card1-eDP-1/`
- `/sys/class/drm/card1-eDP-2/`

---

## Keyboard

### USB Keyboard (Detachable)

```
Bus 003 Device 013: ID 0b05:1b2c ASUSTek Computer, Inc. ASUS Zenbook Duo Keyboard
```

- **Vendor ID**: 0x0b05
- **Product ID**: 0x1b2c
- **Driver**: hid-generic (partial)
- **Features**:
  - Touchpad integrated
  - Backlight control (0-3)
  - Media keys (F1-F12)
  - **Fn key**: Not detected in Linux ⚠️

### Key Mapping (ES-Latin America)

| Key | Default Action | Works? |
|-----|----------------|--------|
| F1 | Mute | ✅ |
| F2 | Volume Down | ✅ |
| F3 | Volume Up | ✅ |
| F4 | Keyboard Backlight | ✅ |
| F5 | Brightness Down | ✅ |
| F6 | Brightness Up | ✅ |
| F7 | Swap Displays | ✅ |
| F9 | Mic Mute | ✅ |
| F10 | Bluetooth | ❌ |
| F11 | Emojis | ❌ |
| F12 | ASUS Software | ❌ |

---

## Touchpad

```
N: Name="Primax Electronics Ltd. ASUS Zenbook Duo Keyboard Touchpad"
```

- **Driver**: hid-multitouch
- **Status**: ✅ Working

---

## Bluetooth

```
Bus 003 Device 006: ID 8087:0033 Intel Corp. AX211 Bluetooth
```

- **Driver**: btintel
- **Status**: ✅ Working
- **Note**: Keyboard can connect via Bluetooth for wireless use

---

## Webcam

```
Bus 003 Device 004: ID 3277:0055 Shinetech USB2.0 FHD UVC WebCam
```

- **Driver**: uvcvideo
- **Status**: ✅ Working
- **Resolution**: 5K capable (but USB 2.0 limits to 1080p)

---

## Sensors

### Accelerometer (for auto-rotation)
- **Driver**: iio-sensor-proxy
- **Required package**: `iio-sensor-proxy`
- **Command**: `monitor-sensor`

### Other Sensors
- Ambient light sensor
- Hall sensor (for keyboard detection)

---

## Battery

```
Path: /sys/class/power_supply/BAT0/
```

- **Type**: Li-Polymer
- **Charge Control**: Supported via `charge_control_end_threshold`
- **Limit Range**: 40-100%

---

## Backlight Paths

```
/sys/class/backlight/
├── intel_backlight      # Main display brightness
└── card1-eDP-2-backlight # Bottom display brightness
```

---

## Kernel Requirements

- **Minimum**: 6.8+
- **Recommended**: 6.17+
- **Rationale**:
  - 6.8+: Basic Meteor Lake support
  - 6.11+: Fix for RFKILL on keyboard attach/detach
  - 6.17+: Better Arc Graphics support

---

## Known Limitations

1. **Fn Key**: Not detected - media keys work directly
2. **Fn Lock**: Not supported
3. **F10 (Bluetooth)**: Not implemented
4. **F11 (Emojis)**: Not available on Linux
5. **F12 (ASUS Software)**: Not available on Linux
6. **PSR Flickering**: Some users report gamma flicker - fix with `i915.enable_psr=0` kernel param

---

## External References

- [alesya-h/zenbook-duo-2024-ux8406ma-linux](https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux)
- [valirc/zenbook-duo-2024-ux8406ma-daemon](https://github.com/valirc/zenbook-duo-2024-ux8406ma-daemon)
- [zakstam/zenbook-duo-linux](https://github.com/zakstam/zenbook-duo-linux)
- [ASUS Linux kernel patches](https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/3556)