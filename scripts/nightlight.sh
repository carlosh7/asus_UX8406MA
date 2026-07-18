#!/bin/bash
# Simple night light using Redshift

STATE_FILE="/tmp/zenbook-nightlight.state"

case "${1:-toggle}" in
    on)
        if ! pgrep -x redshift >/dev/null; then
            redshift -m randr -O 3500 &
            echo "Night light ON (3500K)"
        fi
        ;;
    off)
        redshift -x 2>/dev/null
        pkill -x redshift 2>/dev/null
        echo "Night light OFF"
        ;;
    toggle)
        if pgrep -x redshift >/dev/null; then
            redshift -x 2>/dev/null
            pkill -x redshift 2>/dev/null
            echo "Night light OFF"
        else
            redshift -m randr -O 3500 &
            echo "Night light ON (3500K)"
        fi
        ;;
    status)
        if pgrep -x redshift >/dev/null; then
            echo "Night light: ON (3500K)"
        else
            echo "Night light: OFF"
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        ;;
esac
