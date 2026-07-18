#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Audio Diagnostic Script
# Checks: PipeWire, EasyEffects, volume levels, kernel modules, errors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

check_ok() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
check_fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }

echo "=============================================="
echo "  Zenbook Duo - Audio Diagnostic"
echo "=============================================="
echo ""

# --- PipeWire Status --------------------------------------------------------

echo -e "${BLUE}=== PipeWire ===${NC}"
if pgrep -x pipewire >/dev/null; then
    check_ok "PipeWire is running"
else
    check_fail "PipeWire is NOT running"
fi

if pgrep -x wireplumber >/dev/null; then
    check_ok "WirePlumber is running"
else
    check_warn "WirePlumber is NOT running (may use PipeWire session manager)"
fi

# --- Audio Sinks ------------------------------------------------------------

echo ""
echo -e "${BLUE}=== Audio Sinks ===${NC}"
SINK_COUNT=$(wpctl status 2>/dev/null | grep -c "Sink:")
if [ "$SINK_COUNT" -gt 0 ]; then
    check_ok "$SINK_COUNT sink(s) available"
else
    check_fail "No audio sinks found"
fi

# Check default speaker sink
DEFAULT_SINK=$(wpctl status 2>/dev/null | grep "\*.*Speaker" | head -1)
if [ -n "$DEFAULT_SINK" ]; then
    SINK_VOL=$(echo "$DEFAULT_SINK" | grep -oP 'vol: \K[0-9.]+')
    SINK_ID=$(echo "$DEFAULT_SINK" | awk '{print $2}')
    
    if [ -n "$SINK_VOL" ]; then
        # Check for over-amplification
        VOL_INT=$(echo "$SINK_VOL" | awk '{printf "%d", $1 * 100}')
        if [ "$VOL_INT" -gt 100 ]; then
            check_warn "Speaker volume: ${VOL_INT}% (OVER-AMPLIFIED - will cause clipping!)"
            echo "         Fix: wpctl set-volume $SINK_ID 1.0"
        elif [ "$VOL_INT" -gt 80 ]; then
            check_ok "Speaker volume: ${VOL_INT}% (normal)"
        else
            check_ok "Speaker volume: ${VOL_INT}%"
        fi
    fi
else
    check_warn "Speaker sink not found"
fi

# --- Kernel Audio Modules ---------------------------------------------------

echo ""
echo -e "${BLUE}=== Kernel Audio Modules ===${NC}"

# Check SOF driver
if lsmod | grep -q "snd_sof_pci_intel_mtl"; then
    check_ok "SOF Intel Meteor Lake driver loaded"
elif lsmod | grep -q "snd_sof"; then
    check_ok "SOF driver loaded"
else
    check_fail "SOF driver NOT loaded"
fi

# Check codec
if lsmod | grep -q "snd_hda_codec_realtek"; then
    check_ok "Realtek HDA codec loaded"
else
    check_warn "Realtek HDA codec not detected"
fi

# Check CS35L41 smart amp
if lsmod | grep -q "snd_hda_scodec_cs35l41"; then
    check_ok "CS35L41 smart amplifier driver loaded"
else
    check_warn "CS35L41 smart amp driver not loaded (may affect speaker quality)"
fi

# Check kernel module options
if [ -f /etc/modprobe.d/zenbook-duo-audio.conf ]; then
    check_ok "Audio modprobe config exists"
    cat /etc/modprobe.d/zenbook-duo-audio.conf | grep -v "^#" | grep -v "^$" | while read line; do
        echo "         $line"
    done
else
    check_warn "No audio modprobe config (using defaults)"
fi

# --- EasyEffects -----------------------------------------------------------

echo ""
echo -e "${BLUE}=== EasyEffects ===${NC}"

if command -v easyeffects &>/dev/null; then
    EE_VER=$(easyeffects --version 2>/dev/null | head -1)
    check_ok "EasyEffects installed: $EE_VER"
else
    check_fail "EasyEffects not installed"
fi

# Check profile
PROFILE_DIR="$HOME/.config/easyeffects/output"
if [ -f "$PROFILE_DIR/ZenbookDuo.json" ]; then
    check_ok "ZenbookDuo profile found"
    
    # Check for broken plugins (Calf)
    if grep -q "calf" "$PROFILE_DIR/ZenbookDuo.json" 2>/dev/null; then
        check_fail "Profile uses Calf plugins (NOT INSTALLED) - will not work!"
        echo "         Fix: Reinstall with updated ZenbookDuo.json"
    elif grep -q "bass_enhancer" "$PROFILE_DIR/ZenbookDuo.json" 2>/dev/null; then
        check_warn "Profile may use unavailable bass enhancer plugin"
    else
        check_ok "Profile uses available plugins"
    fi
    
    # Check for over-amplification in profile
    INPUT_GAIN=$(python3 -c "
import json
with open('$PROFILE_DIR/ZenbookDuo.json') as f:
    d = json.load(f)
plugins = d.get('output', {})
for key, val in plugins.items():
    if isinstance(val, dict) and 'input-gain' in val:
        print(key, val['input-gain'])
" 2>/dev/null)
    
    if echo "$INPUT_GAIN" | grep -qE "[3-9]\.|[1-9][0-9]"; then
        check_warn "Profile has high input gain (may cause clipping): $INPUT_GAIN"
    fi
else
    check_warn "ZenbookDuo profile not found in $PROFILE_DIR"
fi

# --- Audio Levels -----------------------------------------------------------

echo ""
echo -e "${BLUE}=== Audio Levels ===${NC}"

# Check ALSA mixer
MASTER_VOL=$(amixer -c 0 sget Master 2>/dev/null | grep -oP '\[\K[0-9]+%' | head -1)
if [ -n "$MASTER_VOL" ]; then
    check_ok "Master volume: $MASTER_VOL"
else
    check_warn "Cannot read master volume"
fi

# Check speaker
SPEAKER_VOL=$(amixer -c 0 sget Speaker 2>/dev/null | grep -oP '\[\K[0-9]+%' | head -1)
if [ -n "$SPEAKER_VOL" ]; then
    check_ok "Speaker volume: $SPEAKER_VOL"
else
    check_warn "Cannot read speaker volume"
fi

# --- Recent Errors ----------------------------------------------------------

echo ""
echo -e "${BLUE}=== Recent Audio Errors ===${NC}"

AUDIO_ERRORS=$(journalctl -b --no-pager -p err 2>/dev/null | grep -iE "audio|sound|snd|sof|hda|codec" | tail -5)
if [ -n "$AUDIO_ERRORS" ]; then
    check_warn "Audio-related errors in journal:"
    echo "$AUDIO_ERRORS" | while read line; do
        echo "         $line"
    done
else
    check_ok "No audio errors in current boot"
fi

# --- Summary ----------------------------------------------------------------

echo ""
echo "=============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "=============================================="

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "  Some critical issues were found."
    echo "  Run 'sudo ./install/install.sh' to fix common problems."
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo "  Some warnings detected. Audio may not be optimal."
    exit 0
else
    echo ""
    echo -e "  ${GREEN}Audio system looks healthy!${NC}"
    exit 0
fi
