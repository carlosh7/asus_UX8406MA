#!/usr/bin/env python3

import sys
import usb.core
import usb.util

VENDOR_ID = 0x0b05
PRODUCT_ID = 0x1b2c
REPORT_ID = 0x5A
WVALUE = 0x035A
WINDEX = 4
WLENGTH = 16

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <mode>")
    print("  0: Multimedia keys (default)")
    print("  1: Function keys (F1-F12)")
    sys.exit(1)

try:
    mode = int(sys.argv[1])
    if mode < 0 or mode > 1:
        raise ValueError
except ValueError:
    print("Invalid mode. Must be 0 or 1.")
    sys.exit(1)

data = [0] * WLENGTH
data[0] = REPORT_ID
data[1] = 0xBA
data[2] = 0xC5
data[3] = 0xC1 # 0xC1 is for Fn Lock, 0xC4 is for Backlight
data[4] = mode

dev = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID)

if dev is None:
    print(f"Device not found (Vendor ID: 0x{VENDOR_ID:04X}, Product ID: 0x{PRODUCT_ID:04X})")
    sys.exit(1)

if dev.is_kernel_driver_active(WINDEX):
    try:
        dev.detach_kernel_driver(WINDEX)
    except usb.core.USBError as e:
        print(f"Could not detach kernel driver: {str(e)}")
        sys.exit(1)

try:
    bmRequestType = 0x21
    bRequest = 0x09
    wValue = WVALUE
    wIndex = WINDEX
    ret = dev.ctrl_transfer(bmRequestType, bRequest, wValue, wIndex, data, timeout=1000)
    if ret != WLENGTH:
        print(f"Warning: Only {ret} bytes sent out of {WLENGTH}.")
    else:
        mode_str = "Function keys (F1-F12)" if mode == 1 else "Multimedia keys"
        print(f"Keyboard mode set to: {mode_str}")
except usb.core.USBError as e:
    print(f"Control transfer failed: {str(e)}")
    usb.util.release_interface(dev, WINDEX)
    sys.exit(1)

usb.util.release_interface(dev, WINDEX)
try:
    dev.attach_kernel_driver(WINDEX)
except usb.core.USBError:
    pass

sys.exit(0)
