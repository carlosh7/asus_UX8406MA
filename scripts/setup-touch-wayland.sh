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
echo "  ELAN9008 04f3:425b (superior) -> eDP-1"
echo "  ELAN9009 04f3:425a (inferior) -> eDP-2"
echo "  ⚠️ Verificado físicamente en hardware real ago-2026: el nº de modelo" 
echo "     del controlador NO indica la posición física del panel."

"$SCRIPT_DIR/touch-remap.sh"
