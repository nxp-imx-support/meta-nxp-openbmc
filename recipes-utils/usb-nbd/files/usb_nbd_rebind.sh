#!/bin/sh
#SPDX-License-Identifier: Apache-2.0
#Copyright 2026 NXP

GADGET="/sys/kernel/config/usb_gadget/mass-storage"
UDC="$GADGET/UDC"
NBD="/dev/nbd0"

[ -e "$NBD" ] || exit 0

SIZE=$(cat /sys/block/nbd0/size 2>/dev/null)
[ -n "$SIZE" ] && [ "$SIZE" != "0" ] || exit 0

[ -d "$GADGET/functions" ] || exit 0

FUNC=$(ls "$GADGET/functions" 2>/dev/null | grep '^mass_storage\.' | head -n1)
[ -n "$FUNC" ] || exit 0

FUNC_PATH="$GADGET/functions/$FUNC"

LUN=$(ls "$FUNC_PATH" 2>/dev/null | grep '^lun\.' | head -n1)
[ -n "$LUN" ] || exit 0

LUN_PATH="$FUNC_PATH/$LUN"

logger "[usb-nbd] Using function=$FUNC LUN=$LUN for $NBD"


echo "" > "$UDC" 2>/dev/null || true
sleep 1

echo 1 > "$LUN_PATH/ro"
echo 1 > "$LUN_PATH/removable"
echo 1 > "$LUN_PATH/cdrom"
echo "$NBD" > "$LUN_PATH/file"

# --- Rebind gadget ---
echo ci_hdrc.0 > "$UDC"

logger "[usb-nbd] USB mass storage rebound successfully"
