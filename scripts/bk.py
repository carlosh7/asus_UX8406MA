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
    print(f"Usage: {sys.argv[0]} <level>")
    sys.exit(1)

try:
    level = int(sys.argv[1])
    if level < 0 or level > 3:
        raise ValueError
except ValueError:
    print("Invalid level. Must be an integer between 0 and 3.")
    sys.exit(1)

data = [0] * WLENGTH
data[0] = REPORT_ID
data[1] = 0xBA
data[2] = 0xC5
data[3] = 0xC4
data[4] = level

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
        print(f"Keyboard backlight set to level {level}")
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