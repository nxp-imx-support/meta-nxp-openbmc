# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

SUMMARY = "NXP i.MX95 USB HID forwarder"
DESCRIPTION = "Reads USB HID input events from /dev/input/eventX on USB \
port A and forwards them as USB HID reports to /dev/hidg0 (keyboard), \
/dev/hidg1 (abs mouse), /dev/hidg2 (rel mouse) on USB port C. \
Only active when kvm_mode=pcie_video_usb_hid in /etc/kvm.conf."

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://usb-hid-forwarder.c;md5=401a01f26bd3912c2a4e1f652df57736"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = "file://usb-hid-forwarder.c \
           file://usb-hid-forwarder.service"

S = "${UNPACKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "usb-hid-forwarder.service"
SYSTEMD_AUTO_ENABLE = "enable"


do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${S}/usb-hid-forwarder.c \
        -o ${B}/usb-hid-forwarder \
        -lpthread
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/usb-hid-forwarder ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/usb-hid-forwarder.service \
        ${D}${systemd_system_unitdir}/
}

