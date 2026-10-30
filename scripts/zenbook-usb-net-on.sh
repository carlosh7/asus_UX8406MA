#!/bin/bash
# ============================================================================
# zenbook-usb-net-on.sh — quita autosuspend al NIC USB recién aparecido
#
# Ronda 10: la lógica vive en un script porque el RUN de udev no admite
# $(...) ni variables de shell ($D) — udevd rechazaba la regla anterior con
# "invalid substitution type" y nunca se ejecutaba (hallazgo N2, ronda 9).
# La regla 99-zenbook-usb-net.rules solo pasa %k (nombre de la interfaz).
# ============================================================================
iface="${1:-}"
[ -n "$iface" ] || exit 0

dev=$(readlink -f "/sys/class/net/$iface/device" 2>/dev/null) || exit 0
[ -n "$dev" ] || exit 0

echo on > "$dev/../../power/control" 2>/dev/null || true
echo -1 > "$dev/../../power/autosuspend" 2>/dev/null || true
exit 0
