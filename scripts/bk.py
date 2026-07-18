#!/usr/bin/env python3
"""
Zenbook Duo Keyboard Backlight Control
Supports both USB HID and Bluetooth GATT
"""

import sys
import subprocess
import os

# USB HID constants
USB_VENDOR_ID = 0x0b05
USB_PRODUCT_ID = 0x1b2c
USB_REPORT_ID = 0x5A
USB_WVALUE = 0x035A
USB_WINDEX = 4
USB_WLENGTH = 16

# Bluetooth constants
BT_MAC_FILE = "/tmp/zenbook-bt-mac"
BT_GATT_SERVICE = "service001b"
BT_GATT_CHAR = "char003b"
BT_MAGIC_BYTES = "0xba 0xc5 0xc4"

def is_usb_connected():
    """Check if keyboard is connected via USB"""
    try:
        import usb.core
        dev = usb.core.find(idVendor=USB_VENDOR_ID, idProduct=USB_PRODUCT_ID)
        return dev is not None
    except:
        return False

def get_bt_mac():
    """Get Bluetooth MAC address of the keyboard"""
    # Check cached MAC
    if os.path.exists(BT_MAC_FILE):
        with open(BT_MAC_FILE, 'r') as f:
            mac = f.read().strip()
            if mac:
                return mac
    
    # Find keyboard via bluetoothctl
    try:
        result = subprocess.run(['bluetoothctl', 'devices'], capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if 'ASUS Zenbook Duo Keyboard' in line:
                mac = line.split(' ')[1]
                # Cache the MAC
                with open(BT_MAC_FILE, 'w') as f:
                    f.write(mac)
                return mac
    except:
        pass
    
    return None

def is_bt_connected():
    """Check if keyboard is connected via Bluetooth"""
    mac = get_bt_mac()
    if not mac:
        return False
    
    try:
        result = subprocess.run(['bluetoothctl', 'info', mac], capture_output=True, text=True)
        return 'Connected: yes' in result.stdout
    except:
        return False

def set_backlight_usb(level):
    """Set keyboard backlight via USB HID"""
    try:
        import usb.core
        import usb.util
        
        dev = usb.core.find(idVendor=USB_VENDOR_ID, idProduct=USB_PRODUCT_ID)
        if dev is None:
            print(f"USB device not found")
            return False
        
        if dev.is_kernel_driver_active(USB_WINDEX):
            try:
                dev.detach_kernel_driver(USB_WINDEX)
            except usb.core.USBError as e:
                print(f"Could not detach kernel driver: {e}")
                return False
        
        data = [0] * USB_WLENGTH
        data[0] = USB_REPORT_ID
        data[1] = 0xBA
        data[2] = 0xC5
        data[3] = 0xC4
        data[4] = level
        
        bmRequestType = 0x21
        bRequest = 0x09
        wValue = USB_WVALUE
        wIndex = USB_WINDEX
        
        ret = dev.ctrl_transfer(bmRequestType, bRequest, wValue, wIndex, data, timeout=1000)
        if ret != USB_WLENGTH:
            print(f"Warning: Only {ret} bytes sent out of {USB_WLENGTH}.")
        
        usb.util.release_interface(dev, USB_WINDEX)
        try:
            dev.attach_kernel_driver(USB_WINDEX)
        except:
            pass
        
        print(f"Keyboard backlight set to level {level} (USB)")
        return True
    except Exception as e:
        print(f"USB error: {e}")
        return False

def set_backlight_bt(level):
    """Set keyboard backlight via Bluetooth GATT"""
    mac = get_bt_mac()
    if not mac:
        print("Bluetooth keyboard not found")
        return False
    
    # Convert MAC format for GATT path
    gatt_mac = mac.replace(':', '_')
    
    # Magic bytes for backlight control
    magic = f"0xba 0xc5 0xc4 {level:02x}"
    
    try:
        # Create bluetoothctl command
        cmd = f"""bluetoothctl &>/dev/null << EOF
gatt.select-attribute /org/bluez/hci0/dev_{gatt_mac}/{BT_GATT_SERVICE}/{BT_GATT_CHAR}
gatt.write "{magic}"
EOF"""
        
        result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            print(f"Keyboard backlight set to level {level} (Bluetooth)")
            return True
        else:
            print(f"Bluetooth GATT write failed")
            return False
    except Exception as e:
        print(f"Bluetooth error: {e}")
        return False

def set_backlight(level):
    """Set keyboard backlight using best available method"""
    if is_usb_connected():
        return set_backlight_usb(level)
    elif is_bt_connected():
        return set_backlight_bt(level)
    else:
        print("No keyboard connected (USB or Bluetooth)")
        return False

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <level>")
        print("Levels: 0=Off, 1=Low, 2=Mid, 3=High")
        sys.exit(1)
    
    try:
        level = int(sys.argv[1])
        if level < 0 or level > 3:
            raise ValueError
    except ValueError:
        print("Invalid level. Must be an integer between 0 and 3.")
        sys.exit(1)
    
    success = set_backlight(level)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
