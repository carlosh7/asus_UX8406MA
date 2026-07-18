#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Webcam Diagnostic & Calibration Script
# Tests: resolution, format, controls, quality
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CAM_DEVICE="/dev/video0"
PASS=0
WARN=0
FAIL=0

check_ok() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
check_fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }

echo "=============================================="
echo "  Zenbook Duo - Webcam Diagnostic"
echo "=============================================="
echo ""

# --- Hardware Detection -----------------------------------------------------

echo -e "${BLUE}=== Hardware ===${NC}"

# Check USB device
CAMERA=$(lsusb 2>/dev/null | grep -i "3277:0055")
if [ -n "$CAMERA" ]; then
    check_ok "Camera detected: $CAMERA"
else
    check_fail "Camera not found"
fi

# Check video device
if [ -c "$CAM_DEVICE" ]; then
    check_ok "Video device exists: $CAM_DEVICE"
else
    check_fail "Video device not found: $CAM_DEVICE"
fi

# Check driver
DRIVER=$(cat /sys/class/video4linux/video0/device/driver/module/drivers/*/module/description 2>/dev/null | head -1)
if echo "$DRIVER" | grep -qi "uvc"; then
    check_ok "Driver: UVC Video"
else
    check_warn "Driver: ${DRIVER:-unknown}"
fi

echo ""

# --- Device Status ----------------------------------------------------------

echo -e "${BLUE}=== Device Status ===${NC}"

# Check if camera is in use
USER_PID=$(fuser "$CAM_DEVICE" 2>/dev/null | tr -d ' ')
if [ -n "$USER_PID" ]; then
    PROCESS=$(ps -p "$USER_PID" -o comm= 2>/dev/null)
    check_warn "Camera IN USE by: $PROCESS (PID: $USER_PID)"
    echo "         Close $PROCESS to test the camera"
else
    check_ok "Camera is FREE"
fi

echo ""

# --- Supported Formats (via ffmpeg) ----------------------------------------

echo -e "${BLUE}=== Supported Formats ===${NC}"

if command -v ffmpeg &>/dev/null && [ -z "$USER_PID" ]; then
    # Get device capabilities
    CAPS=$(ffmpeg -f v4l2 -list_formats all -i "$CAM_DEVICE" 2>&1)
    
    if echo "$CAPS" | grep -q "Video raw"; then
        check_ok "Raw formats supported"
        echo "$CAPS" | grep "Video raw" | head -5 | while read line; do
            echo "         $line"
        done
    fi
    
    if echo "$CAPS" | grep -q "Video codec"; then
        check_ok "Compressed formats supported"
        echo "$CAPS" | grep "Video codec" | head -5 | while read line; do
            echo "         $line"
        done
    fi
    
    # Check for specific resolutions
    if echo "$CAPS" | grep -qi "1920x1080\|1080p"; then
        check_ok "1080p (Full HD) supported"
    elif echo "$CAPS" | grep -qi "1280x720\|720p"; then
        check_warn "Max resolution: 720p (not Full HD)"
    fi
    
    if echo "$CAPS" | grep -qi "mjpeg\|MJPG"; then
        check_ok "MJPEG format available (better performance)"
    fi
    
    if echo "$CAPS" | grep -qi "yuyv\|YUYV"; then
        check_ok "YUYV format available (uncompressed)"
    fi
else
    check_warn "Cannot list formats (camera in use or ffmpeg not available)"
fi

echo ""

# --- Video Controls ---------------------------------------------------------

echo -e "${BLUE}=== Video Controls ===${NC}"

if [ -z "$USER_PID" ] && command -v v4l2-ctl &>/dev/null; then
    # List controls
    CONTROLS=$(v4l2-ctl -d "$CAM_DEVICE" --list-ctrls 2>&1)
    
    if echo "$CONTROLS" | grep -qi "brightness"; then
        check_ok "Brightness control available"
        echo "$CONTROLS" | grep -i brightness | while read line; do
            echo "         $line"
        done
    fi
    
    if echo "$CONTROLS" | grep -qi "contrast"; then
        check_ok "Contrast control available"
    fi
    
    if echo "$CONTROLS" | grep -qi "saturation"; then
        check_ok "Saturation control available"
    fi
    
    if echo "$CONTROLS" | grep -qi "white_balance\|whitebalance"; then
        check_ok "White balance control available"
    fi
    
    if echo "$CONTROLS" | grep -qi "exposure"; then
        check_ok "Exposure control available"
    fi
    
    if echo "$CONTROLS" | grep -qi "gain"; then
        check_ok "Gain control available"
    fi
    
    if echo "$CONTROLS" | grep -qi "backlight"; then
        check_ok "Backlight compensation available"
    fi
else
    check_warn "Cannot list controls (v4l2-ctl not available or camera in use)"
fi

echo ""

# --- UVC Controls (via sysfs) ----------------------------------------------

echo -e "${BLUE}=== UVC Extension Units ===${NC}"

# Check for UVC extension units
EXT_DIR="/sys/bus/usb/drivers/uvcvideo/3-9:1.0"
if [ -d "$EXT_DIR" ]; then
    check_ok "UVC driver attached"
else
    check_warn "UVC driver directory not found"
fi

echo ""

# --- Test Capture -----------------------------------------------------------

echo -e "${BLUE}=== Test Capture ===${NC}"

if [ -z "$USER_PID" ] && command -v ffmpeg &>/dev/null; then
    # Try to capture a test frame
    TEST_FILE="/tmp/webcam-test.jpg"
    
    echo "  Capturing test frame..."
    timeout 3 ffmpeg -f v4l2 -video_size 1280x720 -i "$CAM_DEVICE" -frames:v 1 -y "$TEST_FILE" 2>/dev/null
    
    if [ -f "$TEST_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$TEST_FILE" 2>/dev/null)
        if [ "$FILE_SIZE" -gt 1000 ]; then
            check_ok "Test capture successful (${FILE_SIZE} bytes)"
            echo "         Saved to: $TEST_FILE"
        else
            check_warn "Test capture file too small (${FILE_SIZE} bytes)"
        fi
    else
        check_warn "Test capture failed"
    fi
    
    # Try 1080p
    TEST_FILE_1080="/tmp/webcam-test-1080.jpg"
    timeout 3 ffmpeg -f v4l2 -video_size 1920x1080 -i "$CAM_DEVICE" -frames:v 1 -y "$TEST_FILE_1080" 2>/dev/null
    
    if [ -f "$TEST_FILE_1080" ]; then
        FILE_SIZE=$(stat -c%s "$TEST_FILE_1080" 2>/dev/null)
        if [ "$FILE_SIZE" -gt 1000 ]; then
            check_ok "1080p capture successful (${FILE_SIZE} bytes)"
        else
            check_warn "1080p capture failed (file too small)"
        fi
    else
        check_warn "1080p capture not supported or failed"
    fi
else
    check_warn "Cannot test capture (camera in use)"
fi

echo ""

# --- PipeWire/Portal -------------------------------------------------------

echo -e "${BLUE}=== PipeWire Video ===${NC}"

if pgrep -x pipewire >/dev/null; then
    check_ok "PipeWire running"
    
    # Check if webcam is exposed via PipeWire
    PW_VIDEO=$(wpctl status 2>/dev/null | grep -c "WebCam")
    if [ "$PW_VIDEO" -gt 0 ]; then
        check_ok "WebCam available in PipeWire ($PW_VIDEO streams)"
    else
        check_warn "WebCam not exposed in PipeWire"
    fi
else
    check_warn "PipeWire not running"
fi

# Check xdg-desktop-portal
if pgrep -f "xdg-desktop-portal" >/dev/null; then
    check_ok "Desktop portal running (for screen sharing)"
else
    check_warn "Desktop portal not running"
fi

echo ""

# --- Kernel Messages -------------------------------------------------------

echo -e "${BLUE}=== Kernel Messages ===${NC}"

UVC_ERRORS=$(dmesg 2>/dev/null | grep -c "uvcvideo.*error\|uvcvideo.*fail" || echo "0")
if [ "$UVC_ERRORS" -gt 0 ]; then
    check_warn "Found $UVC_ERRORS UVC error messages"
    dmesg 2>/dev/null | grep "uvcvideo.*error\|uvcvideo.*fail" | tail -3 | while read line; do
        echo "         $line"
    done
else
    check_ok "No UVC errors in kernel log"
fi

echo ""

# --- Summary ----------------------------------------------------------------

echo "=============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "=============================================="

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "  ${RED}Some critical issues found.${NC}"
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Some warnings detected.${NC} Camera may not be optimal."
    exit 0
else
    echo ""
    echo -e "  ${GREEN}Camera system looks healthy!${NC}"
    exit 0
fi
