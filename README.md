# ASUS Zenbook Duo 2024 Linux — UX8406MA Driver & Utilities

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-4EA94B.svg)](https://www.linux.org/)
[![Distro](https://img.shields.io/badge/Ubuntu-24.04%2B-E95420.svg)](#supported-distributions)
[![Arch](https://img.shields.io/badge/Arch-Linux-1793D1.svg)](#supported-distributions)

**One-command, self-verifying hardware support for the ASUS Zenbook Duo 2024 (UX8406MA).**

Install, configure, and verify — all with a single script. No manual steps, no hardcoded usernames. Core install is AI-free; pass `--with-npu` to optionally add the Intel NPU driver + Level Zero (AI acceleration). The installer downloads the **latest** compatible drivers automatically and verifies their SHA256 against the GitHub release.

---

## ✨ What This Gives You

| Feature | What it does |
|---------|--------------|
| 🖥️ **Dual Screen Management** | Bottom screen auto-switches when the keyboard is detached/attached |
| 👆 **Touch Mapping** | Both screens respond correctly to touch & stylus |
| ⌨️ **Keyboard Backlight** | Adaptive, with idle-off + 1s wake, debounce |
| 🌗 **Adaptive Brightness** | Screen brightness follows ambient light |
| 🌡️ **Thermal Control** | Auto fan profile (quiet/balanced/performance) |
| 🔊 **Audio** | EasyEffects profile for the 4-speaker Harman Kardon system + mic boost |
| 🔋 **Battery Protection** | Charge limit (default 80%) extends battery life |
| 💾 **SSD Health** | NVMe SMART monitoring |
| 🔌 **USB Power Fixes** | Bluetooth/keyboard autosuspend corrections (wake fixes) |
| 🌙 **Night Light** | Wayland-aware GNOME night light |
| 📋 **Self-Verification** | `zenbook-health-check.sh` validates everything after install |

> **No** SSH, firewall, Docker, or Ollama. This project is laser-focused on making the hardware work — nothing else.

---

## 🚀 Quick Install (single command)

```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git && cd asus_UX8406MA && sudo ./install/install.sh
```

That's it. The installer:

1. Installs dependencies & compiles the daemon
2. Downloads the **latest** Intel NPU driver + Level Zero loader (auto-detected via GitHub API / PPA)
3. Installs scripts, udev rules, systemd services
4. **Starts all services immediately**
5. Runs `zenbook-health-check.sh` automatically and reports the result

Then **reboot** and re-run `zenbook-health-check.sh` to confirm the kernel modules are loaded.

---

## ✅ After Install

```bash
zenbook-health-check.sh    # Self-verifies: services, USB autosuspend, audio, touch, night light, thermal
duo status                 # Display/state status
systemctl is-active zenbook-duo   # Daemon status
```

---

## 🖥️ Supported Hardware

| Component | Detail |
|-----------|--------|
| **Model** | ASUS Zenbook Duo 2024 (UX8406MA) |
| **CPU** | Intel Core Ultra 9 185H (16C/22T) |
| **RAM** | 32GB LPDDR5x |
| **Displays** | Dual 3K OLED, 2880×1800 @ 120Hz |
| **Touch** | Dual ELAN controllers |
| **Audio** | Realtek ALC294 + CS35L41 smart amps |
| **WiFi/BT** | Intel Meteor Lake CNVi |
| **Keyboard** | USB + Bluetooth dual-mode |
| **SSD** | WD PC SN560 1TB NVMe |

---

## 📖 Documentation

| Doc | Content |
|-----|---------|
| [Installation (detailed)](docs/INSTALL.md) | Step-by-step, beginner friendly |
| [Usage & Commands](USAGE.md) | Full `duo` command reference |
| [Hardware Specs](SPEC.md) | Component/driver matrix |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues & fixes |
| [Hardware Details](docs/HARDWARE.md) | Internals |
| [System Hardening & Tuning](docs/SYSTEM-HARDENING.md) | Performance & battery tuning |

---

## 🗺️ Supported Distributions

| Distro | Status |
|--------|--------|
| Ubuntu 24.04+ | ✅ Full support (tested on 26.04/Wayland) |
| Debian 12+ | ✅ Full support |
| Arch Linux | ✅ Full support |
| Pop!_OS / Linux Mint | ✅ Should work |

**Wayland is fully supported** (GNOME). X11 works for most features.

---

## 📦 What Gets Installed

**Systemd services** (all auto-started, auto-enabled):

| Service | Purpose |
|---------|---------|
| `zenbook-duo` | Main daemon (display, keyboard detection) |
| `zenbook-light-monitor` | Keyboard backlight v4 |
| `zenbook-thermal` | Auto fan profile |
| `zenbook-adaptive-brightness` | Ambient brightness |
| `brightness-sync` | Dual-screen brightness sync |
| `zenbook-auto-display` | Keyboard attach/detach display switch |
| `zenbook-config` | Restore config on boot |
| `battery-limit` | 80% charge limit |
| `zenbook-nightlight` | Night light |
| `mic-boost` | Mic gain boost |
| `zenbook-bt-keyboard` | Bluetooth keyboard keycode mapper |
| `zenbook-suspend-backlight` | Keyboard light on resume |

**Diagnostics & tools:** `zenbook-health-check.sh`, `system-health.sh`, `ssd-health.sh`, `audio-diagnose.sh`, `wifi-diagnose.sh`, `test_hardware.sh`, `webcam-diagnose.sh`, and more.

---

## 🤝 Credits

Based on work by:
- [alesya-h](https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux) — Original display scripts
- [valirc](https://github.com/valirc/zenbook-duo-2024-ux8406ma-daemon) — C daemon
- [zakstam](https://github.com/zakstam/zenbook-duo-linux) — Rust implementation
- [fmstrat](https://github.com/fmstrat/zenbook-duo-linux) — Alternative approach

---

## 📄 License

MIT