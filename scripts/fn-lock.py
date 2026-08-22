#!/usr/bin/env python3
"""
Zenbook Duo - Fn Lock toggle
mode 0 = Multimedia keys | mode 1 = Function keys (F1-F12)

v2 ago-2026: soporte Bluetooth además de USB.
- USB: control transfer pyusb (como v1)
- BT : feature report por hidraw (ioctl HIDIOCSFEATURE) sobre
       /sys/bus/hid/devices/0005:0B05:1B2D.* (el PID cambia a 1B2D en BT)
"""

import sys
import os
import glob
import fcntl

USB_VID, USB_PID = 0x0B05, 0x1B2C          # teclado por USB
BT_PREFIX = "/sys/bus/hid/devices/0005:0B05:1B2D."  # teclado por Bluetooth
REPORT_ID = 0x5A
WVALUE = 0x035A
WINDEX = 4
WLENGTH = 16


def build_payload(mode):
    data = [0] * WLENGTH
    data[0] = REPORT_ID
    data[1] = 0xBA
    data[2] = 0xC5
    data[3] = 0xC1        # 0xC1 Fn Lock (0xC4 sería Backlight)
    data[4] = mode
    return bytes(data)


def set_usb(mode):
    import usb.core
    dev = usb.core.find(idVendor=USB_VID, idProduct=USB_PID)
    if dev is None:
        return False
    try:
        if dev.is_kernel_driver_active(WINDEX):
            dev.detach_kernel_driver(WINDEX)
    except Exception:
        pass
    ret = dev.ctrl_transfer(0x21, 0x09, WVALUE, WINDEX,
                            list(build_payload(mode)), timeout=1000)
    return ret == WLENGTH


def set_bt(mode):
    """Feature report por cada hidraw del teclado BT; basta con que uno acepte."""
    payload = build_payload(mode)
    ioctl_code = (3 << 30) | (len(payload) << 16) | (ord('H') << 8) | 6  # HIDIOCSFEATURE
    sent = False
    last_err = None
    for hdir in sorted(glob.glob(BT_PREFIX + "*")):
        for hr_dir in sorted(glob.glob(hdir + "/hidraw/hidraw*")):
            node = "/dev/" + os.path.basename(hr_dir)
            try:
                fd = os.open(node, os.O_WRONLY | os.O_NONBLOCK)
                try:
                    fcntl.ioctl(fd, ioctl_code, payload)
                    sent = True
                finally:
                    os.close(fd)
            except OSError as e:
                last_err = e
    return sent


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("0", "1"):
        print(f"Usage: {sys.argv[0]} <0|1>")
        print("  0: Multimedia keys (default)")
        print("  1: Function keys (F1-F12)")
        sys.exit(1)
    mode = int(sys.argv[1])

    if set_usb(mode):
        via = "USB"
    elif set_bt(mode):
        via = "Bluetooth"
    else:
        print("ERROR: teclado no encontrado ni por USB ni por Bluetooth")
        if last_err_hint():
            print(f"Detalle BT: {last_err_hint()}")
        sys.exit(1)

    mode_str = "Function keys (F1-F12)" if mode == 1 else "Multimedia keys"
    print(f"Keyboard mode set to: {mode_str} ({via})")


def last_err_hint():
    for hdir in sorted(glob.glob(BT_PREFIX + "*")):
        for hr_dir in sorted(glob.glob(hdir + "/hidraw/hidraw*")):
            node = "/dev/" + os.path.basename(hr_dir)
            if not os.access(node, os.W_OK):
                return f"{node} sin permiso de escritura (¿grupo input?)"
    return "sin hidraw accesible"


if __name__ == "__main__":
    main()
