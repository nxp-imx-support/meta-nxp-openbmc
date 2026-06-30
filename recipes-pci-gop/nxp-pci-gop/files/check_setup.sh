 #!/bin/sh
cat /sys/kernel/debug/devices_deferred && /usr/bin/pci_cfg.sh

IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Fallback if eth0 not available
if [ -z "$IP" ]; then
    IP=$(hostname -I | awk '{print $1}')
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
    printf -v FORMATTED "%-${INNER_WIDTH}s" "$TEXT"
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
print_line "http://$IP:8000/"
print_line "http://$HOST.local:8000/"

print_line ""
print_line "Note:"
print_line "- Use the IP address if mDNS (.local) is unavailable."
print_line "- Ensure your system is connected to the same network."
print_line ""

center_line "$TOP_BOTTOM"
echo ""