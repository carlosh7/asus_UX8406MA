#!/bin/bash
# Toggle Bluetooth status

STATUS=$(rfkill list bluetooth | grep "Soft blocked: yes")

if [ -n "$STATUS" ]; then
    rfkill unblock bluetooth
    notify-send -i bluetooth-active "Bluetooth" "Activado"
else
    rfkill block bluetooth
    notify-send -i bluetooth-offline "Bluetooth" "Desactivado"
fi
