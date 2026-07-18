#!/bin/bash
# ============================================================================
# Zenbook Duo - Webcam Privacy Manager
# Shows indicator when webcam is active, allows blocking
# ============================================================================

BLOCK_FILE="/tmp/webcam-blocked"
STATE_FILE="/tmp/webcam-state"

show_status() {
    if [ -f "$BLOCK_FILE" ]; then
        echo "Webcam: BLOCKED"
    else
        echo "Webcam: ACTIVE"
    fi
}

toggle_block() {
    if [ -f "$BLOCK_FILE" ]; then
        rm "$BLOCK_FILE"
        echo "Webcam unblocked"
    else
        touch "$BLOCK_FILE"
        echo "Webcam blocked"
    fi
}

check_active() {
    for v in /dev/video*; do
        if fuser "$v" >/dev/null 2>&1; then
            echo "ACTIVE: $v is in use"
            return 0
        fi
    done
    echo "No webcam in use"
    return 1
}

case "${1:-status}" in
    status)
        show_status
        ;;
    block)
        toggle_block
        ;;
    check)
        check_active
        ;;
    *)
        echo "Usage: webcam-privacy.sh [status|block|check]"
        ;;
esac
