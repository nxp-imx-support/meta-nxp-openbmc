# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

#!/bin/sh
cat /sys/kernel/debug/devices_deferred && /usr/bin/pci_cfg.sh

IP=$(ip -4 addr show eth0 2>/dev/null \
    | awk '/inet / {split($2,a,"/"); print a[1]; exit}')

if [ -z "$IP" ]; then
    IP=$(ip -4 addr \
        | awk '/inet / && $2 !~ /^127/ {split($2,a,"/"); print a[1]; exit}')
fi

HOST=$(hostname)

WIDTH=$(tput cols 2>/dev/null || echo 80)
BOX_WIDTH=70

center_line() {
    PAD=$(( (WIDTH - BOX_WIDTH) / 2 ))
    printf "%*s%s\n" "$PAD" "" "$1"
}

print_line() {
    TEXT="$1"
    INNER_WIDTH=$((BOX_WIDTH-4))
    FORMATTED=$(printf "%-${INNER_WIDTH}s" "$TEXT")
    center_line "| $FORMATTED |"
}

TOP_BOTTOM=$(printf '=%.0s' $(seq 1 $BOX_WIDTH))

echo ""
center_line "$TOP_BOTTOM"
print_line "i.MX Platform - Remote Access Details"
center_line "$TOP_BOTTOM"

print_line ""
print_line "IP Address:        $IP"
print_line "Hostname:          $HOST.local"
print_line ""

print_line "Access URLs:"
print_line "https://$IP/"
print_line "https://$HOST.local/"

print_line ""
print_line "Note:"
print_line "- Use the IP address if mDNS (.local) is unavailable."
print_line "- Ensure your system is connected to the same network."
print_line ""

center_line "$TOP_BOTTOM"
echo ""