# System Hardening & Performance Tuning

Security, performance, and maintenance optimizations for ASUS Zenbook Duo UX8406MA on Ubuntu 24.04.

---

## Security Hardening

### SSH Hardening (`config/ssh/99-hardened.conf`)

Installed to `/etc/ssh/sshd_config.d/99-hardened.conf`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `PermitRootLogin` | no | Prevent direct root login |
| `PasswordAuthentication` | no | Key-only authentication |
| `PubkeyAuthentication` | yes | Enable public key auth |
| `MaxAuthTries` | 3 | Limit brute force attempts |
| `LoginGraceTime` | 30s | Timeout for authentication |
| `X11Forwarding` | no | Disable unused feature |
| `AllowUsers` | carlosh | Restrict to single user |
| `LogLevel` | VERBOSE | Detailed SSH logging |

**Ciphers restricted to:**
- `chacha20-poly1305@openssh.com`
- `aes256-gcm@openssh.com`
- `aes128-gcm@openssh.com`

### Firewall (UFW)

```bash
# Status
sudo ufw status numbered

# Rules configured:
# 22/tcp   - SSH (anywhere)
# 80/tcp   - HTTP (anywhere)
# 443/tcp  - HTTPS (anywhere)
# 8080/tcp - HTTP Alt (anywhere)
# 5432     - PostgreSQL (localhost only)
# 6379     - Redis (localhost only)
# 11434    - Ollama (localhost only)
# 631      - CUPS (localhost only)
# 3004     - Node dev (localhost only)
# Docker networks (172.16.0.0/12)
```

### Fail2Ban

Active and protecting SSH. Default configuration with 3 retries and 10 minute ban.

### Kernel Hardening (`config/sysctl/99-performance.conf`)

Network security:
- `net.ipv4.conf.all.rp_filter=1` — Anti IP spoofing
- `net.ipv4.conf.all.accept_redirects=0` — No ICMP redirects
- `net.ipv4.tcp_syncookies=1` — SYN flood protection
- `net.ipv4.conf.all.log_martians=1` — Log suspicious packets

---

## Performance Tuning

### CPU Governor

- **Driver**: `intel_pstate` (Hardware P-States)
- **Daemon**: `auto-cpufreq` (snap) — manages governor dynamically
- Switches between `powersave` (idle) and `performance` (load) automatically

```bash
# Monitor CPU frequency
sudo auto-cpufreq --monitor

# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Sysctl Tuning (`config/sysctl/99-performance.conf`)

Memory:
- `vm.swappiness=10` — Prefer RAM over swap
- `vm.dirty_ratio=5` — Flush dirty pages early (SSD-friendly)
- `vm.dirty_background_ratio=2` — Background flush threshold

Network:
- TCP buffer sizes optimized for high-bandwidth
- `net.ipv4.tcp_fastopen=3` — TCP Fast Open
- `net.core.netdev_max_backlog=5000` — Network queue depth

Filesystem:
- `fs.file-max=2097152` — Max open files
- `fs.inotify.max_user_watches=524288` — Inotify watches

### ZRAM Swap

- **Size**: 16GB compressed (50% of 32GB RAM)
- **Algorithm**: lz4 (fastest)
- **Priority**: 100 (used before file swap)

```bash
# Check ZRAM status
cat /proc/swaps
lszram
```

### Battery Protection

- Charge limited to **80%** (extends battery lifespan)
- Applied at boot via `battery-limit.service`

```bash
# Check current limit
cat /sys/class/power_supply/BAT0/charge_control_end_threshold

# Change temporarily
echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```

---

## Automated Maintenance

### Weekly Maintenance (`scripts/weekly-maintenance.sh`)

Runs every **Sunday at 3:00 AM** via cron.

What it does:
1. Docker cleanup (images, volumes, build cache)
2. Remove old snap versions
3. Journal vacuum (100MB limit)
4. Temp file cleanup (older than 7 days)
5. APT cache cleanup
6. Alert if disk > 85%

### Disk Monitoring (`scripts/disk-monitor.sh`)

Runs **every hour** via cron.

- Checks root partition usage
- Desktop notification if > 80% (warning) or > 90% (critical)
- Logs to `/var/log/disk-monitor.log`

### Unattended Upgrades

- Security updates installed automatically
- **Auto-reboot at 02:00 AM** if required
- Config: `/etc/apt/apt.conf.d/50unattended-upgrades`

### Log Rotation (`config/logrotate/zenbook-duo.conf`)

- All `/var/log/zenbook-*.log` files
- Daily rotation, 7 days retention
- Max 1MB per file, compressed

---

## SSD Health Monitoring

### Script: `scripts/ssd-health.sh`

```bash
sudo ssd-health.sh
```

Shows:
- Temperature
- SMART health status
- Wear level (percentage used)
- Power cycles and hours
- Media errors and unsafe shutdowns
- Disk usage

### Manual check

```bash
# Full SMART log
sudo nvme smart-log /dev/nvme0n1

# Temperature only
sudo nvme smart-log /dev/nvme0n1 | grep temperature

# Wear level
sudo nvme smart-log /dev/nvme0n1 | grep percentage_used
```

---

## System Health Dashboard

### Script: `scripts/system-health.sh`

```bash
sudo system-health.sh
```

Shows:
- System info (hostname, kernel, uptime, load)
- CPU (model, governor, frequency)
- Memory (total, used, free, swap, ZRAM)
- Disk usage
- Docker status
- Security status (UFW, Fail2Ban, SSH, updates)
- Key services status
- Last maintenance run

---

## Package Requirements

The installer (`install/install.sh`) installs these additional packages:

| Package | Purpose |
|---------|---------|
| `btop` | Modern system monitor |
| `nvme-cli` | NVMe SSD management |
| `auto-cpufreq` (snap) | Dynamic CPU frequency |
| `openssh-server` | SSH access |

---

## Manual Setup

If not using the installer, apply these manually:

```bash
# 1. Copy sysctl tuning
sudo cp config/sysctl/99-performance.conf /etc/sysctl.d/
sudo sysctl --system

# 2. Copy SSH hardening
sudo cp config/ssh/99-hardened.conf /etc/ssh/sshd_config.d/
sudo systemctl restart ssh

# 3. Copy logrotate config
sudo cp config/logrotate/zenbook-duo.conf /etc/logrotate.d/

# 4. Enable battery limit
sudo cp systemd/battery-limit.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable battery-limit.service

# 5. Install packages
sudo apt install -y btop nvme-cli
sudo snap install auto-cpufreq
sudo auto-cpufreq --install
```
