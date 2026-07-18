#!/bin/bash
# ============================================================================
# Zenbook Duo - Firmware Update Check
# Checks for available firmware updates via fwupd
# ============================================================================

echo "Checking for firmware updates..."

# Check if fwupd is available
if ! command -v fwupdmgr &>/dev/null; then
    echo "fwupd not installed. Install with: sudo apt install fwupd"
    exit 1
fi

# Refresh metadata
sudo fwupdmgr refresh --force 2>/dev/null

# Check for updates
UPDATES=$(sudo fwupdmgr get-updates 2>/dev/null)

if echo "$UPDATES" | grep -q "No updates available"; then
    echo "✅ Firmware is up to date"
    echo "   Current: $(sudo fwupdmgr get-devices 2>/dev/null | grep -A1 "BIOS" | tail -1)"
else
    echo "⚠️  Firmware update available:"
    echo "$UPDATES"
    echo ""
    echo "To install: sudo fwupdmgr update"
fi
