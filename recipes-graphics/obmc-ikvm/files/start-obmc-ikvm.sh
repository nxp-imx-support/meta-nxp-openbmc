#!/bin/sh

# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

CONFIG=/etc/kvm.conf

# Load configuration
[ -f "$CONFIG" ] && . "$CONFIG"

case "$kvm_mode" in
    pcie_kvm)
        KEYBOARD_DEV="/dev/pcikbd"
        MOUSE_DEV="/dev/pciams"
        ;;
    pcie_video_usb_hid)
        KEYBOARD_DEV="/dev/hidg0"
        MOUSE_DEV="/dev/hidg1"
        ;;
    *)
        echo "Invalid kvm_mode: $kvm_mode"
        exit 1
        ;;
esac

# -u (UDC name) is omitted: UDC lifecycle is managed by usb-hid-forwarder.service
# via create_usbhid.sh; --no-udc-manage tells obmc-ikvm not to bind/unbind the UDC.

exec /usr/bin/obmc-ikvm \
    -v /dev/obmc-ikvm \
    -k "$KEYBOARD_DEV" \
    -p "$MOUSE_DEV" \
    -f 30 \
    --no-udc-manage

