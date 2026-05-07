#!/bin/bash
# Cycle keyboard backlight level (0-3)

STATE_FILE="/tmp/kb_backlight_level"
if [ ! -f "$STATE_FILE" ]; then
    echo 3 > "$STATE_FILE"
fi

CURRENT=$(cat "$STATE_FILE")
NEXT=$(( (CURRENT + 1) % 4 ))

sudo /usr/local/bin/bk.py "$NEXT"
echo "$NEXT" > "$STATE_FILE"
