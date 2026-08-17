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

# Set level (runs bk.py with passwordless sudo)
sudo /usr/local/bin/bk.py "$NEW_LEVEL" 2>/dev/null

# Save state
echo "$NEW_LEVEL" > "$STATE_FILE" 2>/dev/null
