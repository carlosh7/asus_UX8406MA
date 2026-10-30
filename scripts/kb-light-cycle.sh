#!/bin/bash
# Cycle Zenbook keyboard backlight level (0 -> 1 -> 2 -> 3 -> 0)

STATE_FILE="/var/lib/zenbook-duo/kb-backlight.state"

# Read current level
LEVEL=0
if [ -f "$STATE_FILE" ]; then
    LEVEL=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
fi

# Validate level is integer
if ! [[ "$LEVEL" =~ ^[0-3]$ ]]; then
    LEVEL=0
fi

# Cycle level
NEW_LEVEL=$(( (LEVEL + 1) % 4 ))

# Set level (bk.py escribe al teclado vía grupo input: sin sudo — M6/H3, ronda 6;
# el sudo anterior generaba 39 fallos de autenticación/7d bajo el keybinding)
/usr/local/bin/bk.py "$NEW_LEVEL" 2>/dev/null

# Save state
echo "$NEW_LEVEL" > "$STATE_FILE" 2>/dev/null

# Ronda 10: marca de ciclo manual — kb-backlight-unified respeta el nivel
# elegido durante MANUAL_HOLD_SEC en vez de aplanarlo con la curva ALS
# (lucha visible 2026-10-29: 4× "set to level 0" en 19 s contra la tecla)
MANUAL_LOCK="${ZB_MANUAL_LOCK:-$(dirname "$STATE_FILE")/kb-backlight.manual}"
mkdir -p "$(dirname "$MANUAL_LOCK")" 2>/dev/null || true
date +%s > "$MANUAL_LOCK" 2>/dev/null || true
