#!/bin/sh
# Bridge the OpenBMC enclosure_identify LED group to the OBMF virtual gpiochip.
#
# The OBMF ICP-over-USB BMC driver (obmf_icp_usb_bmc) exposes an "obmf-gpio"
# gpiochip whose line 0 ("led0") drives the system identify LED shared between
# the i.MX (OpenBMC) and the MCX. That line is a gpiochip line, not a
# /sys/class/leds device, so phosphor-led-sysfs cannot create a physical LED
# backend for it. This service watches the enclosure_identify group's Asserted
# property (the same property the WebUI identify toggle and the id-button
# service drive) and mirrors it onto the gpiochip line.
#
# The line must be actively held: libgpiod v1.6 default exit-mode releases the
# line immediately, and on the OBMF gpiochip a released line keeps its last
# driven level, so the LED never turns off. We therefore hold 1 for on and
# 0 for off using --mode=signal --background.

SVC="xyz.openbmc_project.LED.GroupManager"
IFACE="xyz.openbmc_project.Led.Group"
PROPERTY="Asserted"
GPIO_LABEL="obmf-gpio"
LINE="0"
last=""

# Resolve the enclosure_identify group object path dynamically so this keeps
# working regardless of the exact object tree layout.
find_object() {
    busctl tree "$SVC" --list 2>/dev/null | grep identify | grep -v blink | head -n 1
}

# Resolve the OBMF gpiochip by its label (chip number is not stable).
find_chip() {
    for c in /dev/gpiochip*; do
        name=$(gpioinfo "$(basename "$c")" 2>/dev/null | sed -n '1p')
        case "$name" in
            *"$GPIO_LABEL"*) basename "$c"; return 0 ;;
        esac
    done
    # Fallback to a fixed chip if the label lookup fails.
    echo "gpiochip6"
}

drive() {
    chip=$(find_chip)
    killall gpioset 2>/dev/null
    sleep 1
    gpioset --mode=signal --background "$chip" "$LINE"="$1"
}

while true; do
    obj=$(find_object)
    if [ -n "$obj" ]; then
        val=$(busctl get-property "$SVC" "$obj" "$IFACE" "$PROPERTY" 2>/dev/null | awk '{print $NF}')
        if [ "$val" != "$last" ] && [ -n "$val" ]; then
            case "$val" in
                true)  drive 1 ;;
                false) drive 0 ;;
            esac
            last="$val"
        fi
    fi
    sleep 1
done
