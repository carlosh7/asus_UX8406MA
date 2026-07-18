#!/bin/bash
# SSD Health Dashboard - WD PC SN560 NVMe
# Usage: ssd-health.sh

echo "╔══════════════════════════════════════════════════╗"
echo "║           SSD HEALTH - WD PC SN560              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Temperature
echo "🌡️  TEMPERATURA"
echo "──────────────"
nvme smart-log /dev/nvme0n1 2>/dev/null | grep -E "temperature" || echo "  No disponible"
echo ""

# SMART health
echo "📊 SMART HEALTH"
echo "───────────────"
nvme smart-log /dev/nvme0n1 2>/dev/null | grep -E "percentage_used|available_spare|critical_warning|data_units" || echo "  No disponible"
echo ""

# Power cycles
echo "⚡ CICLOS DE ENERGÍA"
echo "────────────────────"
nvme smart-log /dev/nvme0n1 2>/dev/null | grep -E "power_cycles|power_on_hours" || echo "  No disponible"
echo ""

# Wear level (if available)
echo "📉 WEAR LEVEL"
echo "─────────────"
PERCENT=$(nvme smart-log /dev/nvme0n1 2>/dev/null | grep "percentage_used" | awk '{print $3}' | tr -d '%')
if [ -n "$PERCENT" ]; then
    HEALTH=$((100 - PERCENT))
    echo "  Usado: ${PERCENT}% | Salud: ${HEALTH}%"
    if [ "$PERCENT" -gt 80 ]; then
        echo "  ⚠️  ALERTA: SSD con mucho desgaste"
    elif [ "$PERCENT" -gt 50 ]; then
        echo "  ⚡ Moderado: Considerar respaldo"
    else
        echo "  ✅ Saludable"
    fi
else
    echo "  No disponible"
fi
echo ""

# Errors
echo "🔴 ERRORES"
echo "──────────"
nvme smart-log /dev/nvme0n1 2>/dev/null | grep -E "media_errors|unsafe_shutdowns" || echo "  No disponible"
echo ""

# Disk usage
echo "💾 ESPACIO"
echo "─────────"
df -h / | awk 'NR>1{printf "  Usado: %s / %s (%s)\n", $3, $2, $5}'
