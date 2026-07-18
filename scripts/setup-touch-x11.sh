#!/bin/bash
# ============================================================================
# Zenbook Duo - Touch Mapping Setup (X11)
# Applies correct touch transformation matrices for dual-screen
# ============================================================================

# Device IDs (may change after reboot, detect dynamically)
TOP_TOUCH=$(xinput list --id-only "ELAN9009:00 04F3:425A" 2>/dev/null)
BOT_TOUCH=$(xinput list --id-only "ELAN9008:00 04F3:425B" 2>/dev/null)

if [ -z "$TOP_TOUCH" ] || [ -z "$BOT_TOUCH" ]; then
    echo "Touch devices not found"
    exit 1
fi

echo "Setting touch mapping..."
echo "  Top touch (ELAN9009, id=$TOP_TOUCH) -> eDP-1"
echo "  Bottom touch (ELAN9008, id=$BOT_TOUCH) -> eDP-2"

# Top touch: scale Y by 0.5 (top half of combined display)
xinput set-prop "$TOP_TOUCH" "Coordinate Transformation Matrix" \
    1.0 0.0 0.0 0.0 0.5 0.0 0.0 0.0 1.0

# Bottom touch: scale Y by 0.5 + offset 0.5 (bottom half)
xinput set-prop "$BOT_TOUCH" "Coordinate Transformation Matrix" \
    1.0 0.0 0.0 0.0 0.5 0.5 0.0 0.0 1.0

echo "Touch mapping applied"
