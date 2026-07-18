# ASUS Zenbook Duo 2024 Linux Support — UX8406MA Driver & Utilities

**Complete Linux hardware support for ASUS Zenbook Duo 2024 (UX8406MA).** One-command install for Ubuntu, Arch, and Debian.

---

## What This Does

| Feature | Status |
|---------|--------|
| **Dual Screen Management** | Auto-switch bottom screen on keyboard attach/detach |
| **Touch Screen Mapping** | Both screens respond to touch correctly |
| **Keyboard Backlight** | Auto-adjusts with 30s idle timeout, 1s wake-up, debounce |
| **Adaptive Brightness** | Screen brightness adapts to environment with manual override |
| **Thermal Control** | Auto fan profile (quiet/balanced/performance) based on CPU temp |
| **Audio Profiles** | EasyEffects config for 4-speaker Harman Kardon system |
| **Battery Protection** | Charge limit (default 80%) for longevity |
| **SSD Health Monitoring** | NVMe SMART health, wear level, temperature |
| **CPU Optimization** | auto-cpufreq daemon for dynamic governor management |
| **Security Hardening** | SSH hardening, UFW firewall, Fail2Ban |
| **Performance Tuning** | Sysctl optimization, ZRAM swap, journal limits |
| **Automated Maintenance** | Weekly cleanup, disk monitoring, auto-upgrades |

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
- **CPU**: Intel Core Ultra 9 185H (16 cores, 22 threads)
- **RAM**: 32GB LPDDR5x
- **Display**: Dual 3K OLED (2880x1800 @ 120Hz)
- **Touch**: Dual ELAN touch controllers
- **Audio**: Realtek ALC294 + CS35L41 smart amplifiers
- **WiFi**: Intel Meteor Lake CNVi
- **Keyboard**: USB + Bluetooth dual-mode
- **SSD**: WD PC SN560 1TB NVMe

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
sudo system-health.sh       # Full system dashboard
sudo ssd-health.sh          # SSD health check
fn-lock.sh                  # Fn-lock status

# Maintenance
sudo weekly-maintenance.sh  # Manual cleanup
```

---

## Documentation

- [Installation Guide](docs/INSTALL.md)
- [Command Reference](docs/USAGE.md)
- [Hardware Specs](SPEC.md)
- [System Hardening & Performance](docs/SYSTEM-HARDENING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## Supported Distributions

| Distro | Status |
|--------|--------|
| Ubuntu 24.04+ | Full support |
| Arch Linux | Full support |
| Debian 12+ | Full support |
| Pop!_OS, Mint | Should work |

---

## System Requirements

- Ubuntu 24.04 LTS or newer (GNOME desktop recommended)
- 32GB RAM recommended (for ZRAM optimization)
- NVMe SSD (for health monitoring)

---

## What Gets Installed

### Services (Systemd)
| Service | Purpose |
|---------|---------|
| `zenbook-duo` | Main daemon (display, keyboard detection) |
| `zenbook-light-monitor` | Keyboard backlight v4 (idle, debounce, 1s wake) |
| `zenbook-thermal` | Auto fan profile |
| `zenbook-adaptive-brightness` | Screen brightness adaptation |
| `brightness-sync` | Dual display brightness sync |
| `zenbook-config` | Restore config on boot |
| `battery-limit` | 80% charge limit |
| `auto-cpufreq` | Dynamic CPU governor |

### Scripts
| Script | Purpose |
|--------|---------|
| `system-health.sh` | System health dashboard |
| `ssd-health.sh` | NVMe SSD health check |
| `fn-lock.sh` | Fn-lock status |
| `disk-monitor.sh` | Disk space alerts |
| `weekly-maintenance.sh` | Automated weekly cleanup |

### Packages
| Package | Purpose |
|---------|---------|
| `btop` | Modern system monitor |
| `nvme-cli` | NVMe management |
| `auto-cpufreq` (snap) | CPU frequency optimization |
| `openssh-server` | SSH access |

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
