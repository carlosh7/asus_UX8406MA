#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - Webcam Optimization Script
# Sets optimal camera settings for video calls and recording
# ============================================================================

CAM_DEVICE="/dev/video0"

echo "=============================================="
echo "  Zenbook Duo - Webcam Optimization"
echo "=============================================="
echo ""

# Check if camera is available
if fuser "$CAM_DEVICE" 2>/dev/null | grep -q .; then
    echo "ERROR: Camera is in use by another process."
    echo "  Close the application using the camera and try again."
    echo ""
    echo "  To find what's using it:"
    echo "    fuser $CAM_DEVICE"
    echo "    lsof $CAM_DEVICE"
    exit 1
fi

echo "Camera is available. Applying optimizations..."
echo ""

# --- Reset to defaults -----------------------------------------------------

echo "[1/4] Resetting to defaults..."
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=brightness=128 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=contrast=128 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=saturation=128 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=white_balance_temperature_auto=1 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=exposure_auto=3 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=gain=64 2>/dev/null
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=power_line_frequency=2 2>/dev/null
echo "  Defaults applied"

# --- Optimize for video calls ----------------------------------------------

echo ""
echo "[2/4] Optimizing for video calls..."

# Set reasonable brightness (slightly above midpoint)
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=brightness=140 2>/dev/null && \
    echo "  Brightness: 140 (slightly bright)" || echo "  Brightness: default"

# Boost contrast slightly for sharper image
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=contrast=140 2>/dev/null && \
    echo "  Contrast: 140 (enhanced)" || echo "  Contrast: default"

# Keep saturation natural
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=saturation=130 2>/dev/null && \
    echo "  Saturation: 130 (slightly vivid)" || echo "  Saturation: default"

# Auto white balance (best for most lighting)
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=white_balance_temperature_auto=1 2>/dev/null && \
    echo "  White balance: Auto" || echo "  White balance: default"

# Auto exposure with target brightness
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=exposure_auto=3 2>/dev/null && \
    echo "  Exposure: Auto" || echo "  Exposure: default"

# Reduce noise in low light
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=noise_reduction=128 2>/dev/null && \
    echo "  Noise reduction: 128" || echo "  Noise reduction: not available"

# Power line frequency (50Hz for most countries, 60Hz for Americas)
v4l2-ctl -d "$CAM_DEVICE" --set-ctrl=power_line_frequency=2 2>/dev/null && \
    echo "  Power line frequency: 60Hz" || echo "  Power line frequency: default"

echo ""

# --- Test capture ----------------------------------------------------------

echo "[3/4] Testing capture..."
TEST_FILE="/tmp/webcam-optimized-test.jpg"
timeout 3 ffmpeg -f v4l2 -video_size 1280x720 -i "$CAM_DEVICE" -frames:v 1 -y "$TEST_FILE" 2>/dev/null

if [ -f "$TEST_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$TEST_FILE" 2>/dev/null)
    echo "  Test capture: OK (${FILE_SIZE} bytes)"
    echo "  Saved to: $TEST_FILE"
else
    echo "  Test capture: Failed"
fi

echo ""

# --- Current settings ------------------------------------------------------

echo "[4/4] Current settings:"
v4l2-ctl -d "$CAM_DEVICE" --list-ctrls 2>/dev/null | while read line; do
    echo "  $line"
done

echo ""
echo "=============================================="
echo "  Optimization Complete!"
echo "=============================================="
echo ""
echo "  Settings applied for better video call quality."
echo "  The camera will use these settings until changed."
echo ""
echo "  To test, open any video call app (Zoom, Teams, etc.)"
echo ""
