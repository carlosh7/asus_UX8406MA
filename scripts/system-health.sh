#!/bin/bash
# System Health Dashboard - ASUS Zenbook Duo UX8406MA
# Run: sudo /usr/local/bin/system-health.sh

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SYSTEM HEALTH DASHBOARD - $(date '+%Y-%m-%d %H:%M')          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# System info
echo "📊 SISTEMA"
echo "─────────"
echo "  Hostname:   $(hostname)"
echo "  Kernel:     $(uname -r)"
echo "  Uptime:     $(uptime -p)"
echo "  Load:       $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo ""

# CPU
echo "🖥️  CPU"
echo "─────"
echo "  Model:      Intel Core Ultra 9 185H"
echo "  Governor:   $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "  Freq:       $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.0f MHz", $1/1000}')"
echo ""

# Memory
echo "🧠 MEMORIA"
echo "──────────"
free -h | awk '/^Mem:/ {printf "  Total: %s | Usado: %s | Libre: %s | Buff/Cache: %s\n", $2, $3, $4, $6}'
free -h | awk '/^Swap:/ {printf "  Swap:  %s | Usado: %s | Libre: %s\n", $2, $3, $4}'
echo "  ZRAM:       $(lszram 2>/dev/null | head -1 || echo 'N/A')"
echo ""

# Disk
echo "💾 DISCO"
echo "───────"
df -h / /home 2>/dev/null | awk 'NR>1{printf "  %-12s %s de %s (%s usado)\n", $6, $3, $2, $5}'
echo "  NVMe Temp:  $(sudo nvme smart-log /dev/nvme0n1 2>/dev/null | grep temperature | awk '{print $3}' || echo 'N/A')°C"
echo ""

# Docker
echo "🐳 DOCKER"
echo "────────"
docker system df 2>/dev/null | awk 'NR>1{printf "  %-12s Total: %s | Activo: %s | Reclamable: %s\n", $1, $2, $3, $4}'
echo ""

# Security
echo "🔒 SEGURIDAD"
echo "────────────"
echo "  UFW:        $(sudo ufw status 2>/dev/null | head -1)"
echo "  Fail2Ban:   $(systemctl is-active fail2ban)"
echo "  SSH:        $(systemctl is-active ssh)"
echo "  Updates:    $(apt list --upgradable 2>/dev/null | grep -c upgradable) paquetes pendientes"
echo ""

# Services
echo "⚙️  SERVICIOS CLAVE"
echo "─────────────────"
for svc in docker ollama fail2ban thermald; do
    STATUS=$(systemctl is-active $svc 2>/dev/null || echo "unknown")
    printf "  %-15s %s\n" "$svc" "$STATUS"
done
STATUS=$(systemctl is-active ssh.socket 2>/dev/null || echo "unknown")
printf "  %-15s %s\n" "ssh" "$STATUS"
echo ""

# Last maintenance
echo "🧹 MANTENIMIENTO"
echo "───────────────"
if [ -f /var/log/weekly-maintenance.log ]; then
    echo "  Última ejecución: $(tail -1 /var/log/weekly-maintenance.log | cut -d']' -f1 | tr -d '[')"
else
    echo "  Sin registros de mantenimiento"
fi
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "  Comandos útiles:"
echo "    sudo /usr/local/bin/system-health.sh    # Este dashboard"
echo "    sudo /usr/local/bin/weekly-maintenance.sh  # Limpieza manual"
echo "    sudo ufw status numbered                # Reglas firewall"
echo "    sudo journalctl --disk-usage            # Tamaño del journal"
echo "════════════════════════════════════════════════════════════════"
