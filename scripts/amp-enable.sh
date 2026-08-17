#!/bin/bash
# ============================================================================
# Zenbook Duo - Enable CS35L41 right amplifier
# Detects the sound card dynamically (works regardless of card index)
# ============================================================================

# Find the card exposing the Smart Amplifier / sof-hda-dsp driver
CARD=""
for c in /proc/asound/card*/id; do
    [ -e "$c" ] || continue
    id=$(cat "$c" 2>/dev/null)
    if [ "$id" = "sofhdadsp" ]; then
        CARD=$(basename "$(dirname "$c")" | sed 's/card//')
        break
    fi
done

if [ -z "$CARD" ]; then
    CARD=0
fi

# Enable the right amp firmware load control (numid=5 on R0 DSP)
amixer -c "$CARD" cset numid=5 1 >/dev/null 2>&1
exit 0