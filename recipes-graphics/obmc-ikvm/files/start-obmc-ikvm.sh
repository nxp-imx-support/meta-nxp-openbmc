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

exec /usr/bin/obmc-ikvm \
    -v /dev/obmc-ikvm \
    -k "$KEYBOARD_DEV" \
    -p "$MOUSE_DEV" \
    -u 4c100000.usb \
    -f 30 \
    -deferptrupdate 2 \
    
