#!/bin/bash
# ============================================================================
# Zenbook Duo Linux - WiFi Diagnostic Script
# Checks: driver, signal, errors, power save, firmware
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
echo "  Zenbook Duo - WiFi Diagnostic"
echo "=============================================="
echo ""

# --- Hardware Detection -----------------------------------------------------

echo -e "${BLUE}=== Hardware ===${NC}"
WIFI_DEV=$(lspci 2>/dev/null | grep -i "network\|wifi" | head -1)
if [ -n "$WIFI_DEV" ]; then
    check_ok "WiFi hardware: $WIFI_DEV"
else
    check_fail "No WiFi hardware detected"
fi

# --- Driver Status ----------------------------------------------------------

echo ""
echo -e "${BLUE}=== Driver ===${NC}"

if lsmod | grep -q "iwlwifi"; then
    check_ok "iwlwifi driver loaded"
    
    # Check module parameters
    if [ -f /sys/module/iwlwifi/parameters/power_save ]; then
        PS=$(cat /sys/module/iwlwifi/parameters/power_save 2>/dev/null)
        if [ "$PS" = "0" ] || [ "$PS" = "N" ]; then
            check_ok "Power save: OFF (optimal for stability)"
        else
            check_warn "Power save: ON (may cause connectivity issues)"
            echo "         Fix: echo 'options iwlwifi power_save=0' | sudo tee /etc/modprobe.d/iwlwifi-zenbook.conf"
        fi
    fi
else
    check_fail "iwlwifi driver NOT loaded"
fi

# Check modprobe config
if [ -f /etc/modprobe.d/iwlwifi-zenbook.conf ]; then
    check_ok "Custom iwlwifi config exists"
    cat /etc/modprobe.d/iwlwifi-zenbook.conf | grep -v "^#" | grep -v "^$" | while read line; do
        echo "         $line"
    done
else
    check_warn "No custom iwlwifi config"
fi

# --- Connection Status ------------------------------------------------------

echo ""
echo -e "${BLUE}=== Connection ===${NC}"

# Get WiFi interface
WIFACE=$(ip route show default 2>/dev/null | awk '/wlo1/{print $5}' | head -1)
if [ -z "$WIFACE" ]; then
    WIFACE="wlo1"
fi

if ip link show "$WIFACE" &>/dev/null; then
    check_ok "Interface $WIFACE exists"
    
    # Check if up
    if ip link show "$WIFACE" | grep -q "UP"; then
        check_ok "Interface is UP"
    else
        check_fail "Interface is DOWN"
    fi
else
    check_fail "Interface $WIFACE not found"
fi

# Signal quality
SIGNAL_INFO=$(cat /proc/net/wireless 2>/dev/null | grep "$WIFACE")
if [ -n "$SIGNAL_INFO" ]; then
    QUALITY=$(echo "$SIGNAL_INFO" | awk '{print $3}' | tr -d '.')
    LEVEL=$(echo "$SIGNAL_INFO" | awk '{print $4}' | tr -d '.')
    NOISE=$(echo "$SIGNAL_INFO" | awk '{print $5}' | tr -d '.')
    
    if [ -n "$LEVEL" ] && [ "$LEVEL" -gt 0 ] 2>/dev/null; then
        # Convert to positive dBm (value is already positive from /proc/net/wireless)
        if [ "$LEVEL" -lt 50 ]; then
            check_ok "Signal strength: -${LEVEL} dBm (excellent)"
        elif [ "$LEVEL" -lt 60 ]; then
            check_ok "Signal strength: -${LEVEL} dBm (good)"
        elif [ "$LEVEL" -lt 70 ]; then
            check_warn "Signal strength: -${LEVEL} dBm (fair)"
        else
            check_fail "Signal strength: -${LEVEL} dBm (poor)"
        fi
    fi
    
    # Check for errors
    RETRIES=$(echo "$SIGNAL_INFO" | awk '{print $8}' | tr -d '.')
    MISSED=$(echo "$SIGNAL_INFO" | awk '{print $10}' | tr -d '.')
    if [ -n "$RETRIES" ] && [ "$RETRIES" -gt 100 ] 2>/dev/null; then
        check_warn "High retry count: $RETRIES (may indicate interference)"
    fi
    if [ -n "$MISSED" ] && [ "$MISSED" -gt 50 ] 2>/dev/null; then
        check_warn "Missed beacons: $MISSED (connection may be unstable)"
    fi
else
    check_warn "Cannot read wireless stats"
fi

# --- Soft Lockups ------------------------------------------------------------

echo ""
echo -e "${BLUE}=== Kernel Issues ===${NC}"

LOCKUPS=$(dmesg 2>/dev/null | grep -c "iwlwifi.*stuck\|iwlwifi.*error\|iwlwifi.*firmware" 2>/dev/null || echo "0")
LOCKUPS=$(echo "$LOCKUPS" | tr -d '[:space:]')
if [ -n "$LOCKUPS" ] && [ "$LOCKUPS" -gt 0 ] 2>/dev/null; then
    check_warn "Found $LOCKUPS iwlwifi-related kernel messages"
    dmesg 2>/dev/null | grep "iwlwifi.*stuck\|iwlwifi.*error\|iwlwifi.*firmware" | tail -3 | while read line; do
        echo "         $line"
    done
else
    check_ok "No iwlwifi kernel errors detected"
fi

# Check for soft lockups in general
TOTAL_LOCKUPS=$(dmesg 2>/dev/null | grep -c "soft lockup" 2>/dev/null || echo "0")
TOTAL_LOCKUPS=$(echo "$TOTAL_LOCKUPS" | tr -d '[:space:]')
if [ -n "$TOTAL_LOCKUPS" ] && [ "$TOTAL_LOCKUPS" -gt 0 ] 2>/dev/null; then
    check_warn "Found $TOTAL_LOCKUPS soft lockup events (may affect WiFi)"
else
    check_ok "No soft lockup events detected"
fi

# --- Firmware ----------------------------------------------------------------

echo ""
echo -e "${BLUE}=== Firmware ===${NC}"

FW_VERSION=$(dmesg 2>/dev/null | grep "iwlwifi.*firmware.*version" | tail -1 | grep -oP 'version \K\S+')
if [ -n "$FW_VERSION" ]; then
    check_ok "Firmware version: $FW_VERSION"
else
    check_warn "Cannot determine firmware version"
fi

# Check if firmware file exists
FW_FILE=$(modinfo iwlwifi 2>/dev/null | grep "filename:" | awk '{print $2}')
if [ -n "$FW_FILE" ] && [ -f "$FW_FILE" ]; then
    check_ok "Firmware file exists: $FW_FILE"
else
    check_warn "Cannot verify firmware file"
fi

# --- Network Configuration --------------------------------------------------

echo ""
echo -e "${BLUE}=== Network ===${NC}"

# Check current connection
SSID=$(iw dev "$WIFACE" link 2>/dev/null | grep "SSID:" | awk '{print $2}')
if [ -n "$SSID" ]; then
    check_ok "Connected to: $SSID"
else
    check_warn "Not connected to any network"
fi

# Check IP
IP=$(ip addr show "$WIFACE" 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -n "$IP" ]; then
    check_ok "IP address: $IP"
else
    check_warn "No IP address assigned"
fi

# Check DNS
if [ -f /etc/resolv.conf ]; then
    DNS=$(grep "^nameserver" /etc/resolv.conf | head -1 | awk '{print $2}')
    if [ -n "$DNS" ]; then
        check_ok "DNS server: $DNS"
    fi
fi

# --- Summary ----------------------------------------------------------------

echo ""
echo "=============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "=============================================="

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "  Some critical issues were found."
    echo "  Common fixes:"
    echo "    - sudo modprobe -r iwlwifi && sudo modprobe iwlwifi"
    echo "    - sudo ./install/install.sh (reinstall WiFi config)"
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo "  Some warnings detected. WiFi may not be optimal."
    exit 0
else
    echo ""
    echo -e "  ${GREEN}WiFi system looks healthy!${NC}"
    exit 0
fi
