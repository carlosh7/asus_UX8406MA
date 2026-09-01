#!/bin/bash
# ============================================================================
# deploy.sh — Despliegue repo → host en un solo comando
#
#   sudo ./scripts/deploy.sh            # despliega y reinicia servicios activos
#   sudo ./scripts/deploy.sh --diag     # + volcado de diagnóstico root
#   sudo ./scripts/deploy.sh --no-restart  # despliega sin reiniciar servicios
#
# Idempotente. Mantiene los mismos pasos que install.sh (listas duplicadas
# a propósito: deploy no debe ejecutar el instalador completo).
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="/usr/local/bin"
DIAG=0; RESTART=1
for arg in "$@"; do
    case "$arg" in
        --diag) DIAG=1 ;;
        --no-restart) RESTART=0 ;;
        *) echo "uso: $0 [--diag] [--no-restart]"; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecutar con sudo"; exit 1
fi

echo "== [1/7] Scripts -> $BIN_DIR =="
CORE_SCRIPTS="duo bk.py fn-lock.py wayland-display-mgr.py fnlock-toggle.sh zenbook-doctor.sh resume-display.sh"
SERVICE_SCRIPTS="auto-display.sh start.sh kb-light-cycle.sh toggle-bluetooth.sh setup-hotkeys.sh mic-boost.sh setup-displays.sh kb-backlight-unified.sh adaptive-brightness.sh thermal-monitor.sh audio-diagnose.sh audio-calibrate.sh wifi-diagnose.sh test_hardware.sh webcam-diagnose.sh webcam-optimize.sh bt-keyboard-mapper.py zenbook-config.sh suspend-backlight.sh nightlight.sh ssd-health.sh fn-lock.sh system-health.sh disk-monitor.sh weekly-maintenance.sh zzz-keyboard-light oled-protect.sh webcam-privacy.sh firmware-check.sh zenbook-health-check.sh zenbook-boot-test.sh touch-remap.sh setup-touch-wayland.sh amp-enable.sh"
ALL_SCRIPTS=$(printf '%s\n%s\n' "$CORE_SCRIPTS" "$SERVICE_SCRIPTS" | tr ' ' '\n' | sort -u)
for script in $ALL_SCRIPTS; do
    if [ -f "$REPO_DIR/scripts/$script" ]; then
        install -m 755 "$REPO_DIR/scripts/$script" "$BIN_DIR/$script"
    fi
done
echo "  $(echo "$ALL_SCRIPTS" | wc -l) scripts desplegados"

echo "== [2/7] Daemon C (compilar + instalar) =="
make -C "$REPO_DIR/daemon" clean >/dev/null 2>&1 || true
make -C "$REPO_DIR/daemon" >/dev/null
make -C "$REPO_DIR/daemon" install >/dev/null
echo "  zenbook-duo + zenbook-sendkey compilados e instalados"

echo "== [3/7] Unidades systemd =="
install -m 644 "$REPO_DIR"/systemd/*.service /etc/systemd/system/
install -m 644 "$REPO_DIR"/systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
# User= para las unidades que necesitan sesión gráfica (igual que install.sh)
if [ -n "${SUDO_USER:-}" ]; then
    for unit in zenbook-light-monitor mic-boost; do
        sed -i "/^\[Service\]/a User=$SUDO_USER\nGroup=$SUDO_USER" "/etc/systemd/system/$unit.service"
    done
fi
systemctl daemon-reload
echo "  unidades instaladas (permisos 644)"

echo "== [4/7] Servicios habilitados =="
SERVICES="zenbook-duo.service brightness-sync.service zenbook-light-monitor.service zenbook-thermal.service zenbook-adaptive-brightness.service zenbook-config.service battery-limit.service zenbook-nightlight.service zenbook-suspend-backlight.service zenbook-resume-display.service mic-boost.service zenbook-bt-keyboard.service"
for svc in $SERVICES; do
    systemctl enable "$svc" >/dev/null 2>&1 || true
done
# auto-display deshabilitado por diseño: duplica al daemon C (M7, ronda 6)
systemctl disable zenbook-auto-display.service >/dev/null 2>&1 || true
# Doctor: auto-validación/reparación periódica
systemctl enable --now zenbook-doctor.timer >/dev/null 2>&1 || true
echo "  servicios habilitados (auto-display deshabilitado: duplica al daemon C)"

if [ "$RESTART" -eq 1 ]; then
    echo "== [5/7] Reinicio de servicios que estaban activos =="
    for svc in $SERVICES; do
        if systemctl is-active "$svc" >/dev/null 2>&1; then
            systemctl restart "$svc" && echo "  reiniciado: $svc"
        fi
    done
fi

echo "== [6/7] Permisos de configs del sistema =="
chmod 644 /etc/systemd/system/zenbook*.service /etc/systemd/system/{brightness-sync,battery-limit,mic-boost}.service 2>/dev/null || true
for f in /etc/logrotate.d/zenbook-duo.conf /etc/modprobe.d/xe-gpu-optimize.conf \
         /etc/sysctl.d/99-performance.conf /etc/tlp.d/01-zenbook.conf; do
    if [ -f "$f" ]; then chmod 644 "$f"; fi
done

echo "== [7/7] Verificación rápida =="
systemctl --failed --no-legend | head -5
/usr/local/bin/zenbook-health-check.sh 2>/dev/null | tail -3 || true

if [ "$DIAG" -eq 1 ]; then
    OUT=/tmp/zenbook-diag.txt
    {
        echo "=== xe params ==="
        for p in /sys/module/xe/parameters/*; do echo "$(basename "$p")=$(cat "$p" 2>/dev/null)"; done | grep -E 'fbc|psr|sagv|ips|dc=|panel_replay' || true
        echo "=== tlp-stat -s ==="; tlp-stat -s 2>/dev/null | head -25 || true
        echo "=== nvme smart ==="; nvme smart-log /dev/nvme0 2>/dev/null | grep -E 'critical_warning|percentage_used|media_errors|unsafe_shutdowns' || echo "nvme-cli no instalado"
        echo "=== sudoers ==="; visudo -cf /etc/sudoers.d/zenbook-duo 2>&1 || true
        echo "=== backlights ==="; for bl in /sys/class/backlight/*/; do echo "$bl $(cat "$bl/brightness")/$(cat "$bl/max_brightness")"; done
    } > "$OUT" 2>&1 || true
    chmod 644 "$OUT" 2>/dev/null || true
    echo "Diagnóstico en $OUT"
fi

echo "LISTO"
