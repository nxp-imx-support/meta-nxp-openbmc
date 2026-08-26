#!/bin/sh

# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

CONF_FILE=/etc/kvm.conf

[ -f "$CONF_FILE" ] && . "$CONF_FILE"

KVM_MODE="${kvm_mode:-pcie_video_usb_hid}"

load_module()
{
    if ! lsmod | grep -q "^$1"; then
        echo "Loading $1..."
        modprobe "$1" || {
            echo "Failed to load $1"
            exit 1
        }
    else
        echo "$1 already loaded"
    fi
}


echo "KVM_MODE=$KVM_MODE"

case "$KVM_MODE" in

pcie_kvm)
    echo "PCIe KVM mode"
    load_module stream2v4l2

    ;;

pcie_video_usb_hid)
    echo "PCIe Video + USB HID mode"

    load_module stream2v4l2

    ;;

*)
    echo "Unknown mode $KVM_MODE"
    exit 1
    ;;
esac

echo "load_kvm_modules.sh completed"
exit 0
