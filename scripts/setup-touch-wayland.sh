#!/bin/bash
# ============================================================================
# Zenbook Duo - Touch setup (Wayland)
# Persistente: fija el mapeo táctil correcto en dconf del usuario gráfico.
#
# CORREGIDO ago-2026: antes mapeaba invertido (425b→eDP-1, 425a→eDP-2),
# causando que el touch de la pantalla inferior actuara en la superior.
# Ahora delega en touch-remap.sh (mapeo + layout + drop de privilegios).
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Zenbook Duo - Touch mapping (Wayland)"
echo "  ELAN9009 04f3:425a (superior) -> eDP-1"
echo "  ELAN9008 04f3:425b (inferior) -> eDP-2"

"$SCRIPT_DIR/touch-remap.sh"
