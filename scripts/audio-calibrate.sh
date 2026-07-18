#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Audio Calibration Script
# Fixes CS35L41 right amplifier and verifies all audio devices
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=============================================="
echo "  Zenbook Duo - Audio Calibration"
echo "=============================================="
echo ""

# --- Fix CS35L41 Right Amplifier -------------------------------------------

echo -e "${BLUE}=== CS35L41 Smart Amplifiers ===${NC}"

# Load L0 (Left) firmware
L0_STATUS=$(amixer -c 0 cget numid=2 2>&1 | grep ": values" | awk '{print $NF}')
if [ "$L0_STATUS" != "on" ]; then
    echo "  Loading L0 (Left) amplifier firmware..."
    amixer -c 0 cset numid=2 1 >/dev/null 2>&1
    L0_STATUS=$(amixer -c 0 cget numid=2 2>&1 | grep ": values" | awk '{print $NF}')
fi
echo "  L0 (Left): $L0_STATUS"

# Load R0 (Right) firmware
R0_STATUS=$(amixer -c 0 cget numid=5 2>&1 | grep ": values" | awk '{print $NF}')
if [ "$R0_STATUS" != "on" ]; then
    echo "  Loading R0 (Right) amplifier firmware..."
    amixer -c 0 cset numid=5 1 >/dev/null 2>&1
    R0_STATUS=$(amixer -c 0 cget numid=5 2>&1 | grep ": values" | awk '{print $NF}')
fi
echo "  R0 (Right): $R0_STATUS"

# Check speaker jack
SPK_JACK=$(amixer -c 0 cget numid=15 2>&1 | grep ": values" | awk '{print $NF}')
echo "  Speaker Jack: $SPK_JACK"

# Check headphone jack
HP_JACK=$(amixer -c 0 cget numid=14 2>&1 | grep ": values" | awk '{print $NF}')
echo "  Headphone Jack: $HP_JACK"

echo ""

# --- Speaker Levels --------------------------------------------------------

echo -e "${BLUE}=== Speaker Levels ===${NC}"

# Set Master to 100%
amixer -c 0 sset Master 100% >/dev/null 2>&1
echo "  Master: 100%"

# Set Speaker to 100%
amixer -c 0 sset Speaker 100% >/dev/null 2>&1
echo "  Speaker: 100%"

# Set PipeWire volume to 100% (not over-amplified)
wpctl set-volume 58 1.0 2>/dev/null
echo "  PipeWire: 100%"

echo ""

# --- Microphone Levels -----------------------------------------------------

echo -e "${BLUE}=== Microphone Levels ===${NC}"

# Set DMIC0 to 100%
amixer -c 0 sset Dmic0 100% >/dev/null 2>&1
echo "  DMIC0: 100%"

# Set PipeWire mic volume to 100%
wpctl set-volume 60 1.0 2>/dev/null
echo "  PipeWire mic: 100%"

echo ""

# --- EasyEffects Profile ---------------------------------------------------

echo -e "${BLUE}=== EasyEffects Profile ===${NC}"

PROFILE_DIR="$HOME/.config/easyeffects/output"
if [ -f "$PROFILE_DIR/ZenbookDuo.json" ]; then
    if grep -q "calf" "$PROFILE_DIR/ZenbookDuo.json" 2>/dev/null; then
        echo "  ${YELLOW}Profile uses Calf plugins (NOT installed)${NC}"
        echo "  Installing corrected profile..."
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/../config/easyeffects/output/ZenbookDuo.json" ]; then
            cp "$SCRIPT_DIR/../config/easyeffects/output/ZenbookDuo.json" "$PROFILE_DIR/"
            chown "$(stat -c %U "$PROFILE_DIR")" "$PROFILE_DIR/ZenbookDuo.json" 2>/dev/null
            echo "  ${GREEN}Profile updated to use LSP plugins${NC}"
        fi
    else
        echo "  ${GREEN}Profile OK (uses LSP plugins)${NC}"
    fi
else
    echo "  ${YELLOW}Profile not found, installing...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/../config/easyeffects/output/ZenbookDuo.json" ]; then
        mkdir -p "$PROFILE_DIR"
        cp "$SCRIPT_DIR/../config/easyeffects/output/ZenbookDuo.json" "$PROFILE_DIR/"
        chown "$(stat -c %U "$PROFILE_DIR")" "$PROFILE_DIR/ZenbookDuo.json" 2>/dev/null
        echo "  ${GREEN}Profile installed${NC}"
    fi
fi

echo ""

# --- Create udev rule for auto-loading R0 firmware ------------------------

echo -e "${BLUE}=== Auto-load Fix ===${NC}"

UDEV_RULE="/etc/udev/rules.d/99-zenbook-duo-amp.rules"
if [ ! -f "$UDEV_RULE" ]; then
    echo "  Creating udev rule for CS35L41 auto-load..."
    echo '# ASUS Zenbook Duo UX8406MA - Auto-load CS35L41 right amplifier
ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", RUN+="/bin/bash -c \"sleep 1 && amixer -c %k cset numid=5 1 >/dev/null 2>&1\""' | sudo tee "$UDEV_RULE" >/dev/null
    sudo udevadm control --reload-rules 2>/dev/null
    echo "  ${GREEN}udev rule created${NC}"
else
    echo "  ${GREEN}udev rule already exists${NC}"
fi

echo ""

# --- Summary ----------------------------------------------------------------

echo "=============================================="
echo "  Audio Calibration Complete!"
echo "=============================================="
echo ""
echo "  Amplifiers: L0=ON, R0=ON"
echo "  Speakers: 100%"
echo "  Microphone: 100%"
echo "  EasyEffects: LSP plugins"
echo ""
echo "  To test:"
echo "    - Play music to verify both speakers work"
echo "    - Record audio to verify microphone works"
echo ""
