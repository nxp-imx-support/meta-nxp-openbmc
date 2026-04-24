SUMMARY = "USB NBD rebind script for Virtual Media"
DESCRIPTION = "Installs usb_nbd_rebind.sh and udev rule for Virtual Media"
LICENSE = "CLOSED"

SRC_URI = " \
    file://usb_nbd_rebind.sh \
    file://99-usb-nbd.rules \
"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/usb_nbd_rebind.sh \
        ${D}${bindir}/usb_nbd_rebind.sh

    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/99-usb-nbd.rules \
        ${D}${sysconfdir}/udev/rules.d/99-usb-nbd.rules
}

FILES:${PN} += " \
    ${bindir}/usb_nbd_rebind.sh \
    ${sysconfdir}/udev/rules.d/99-usb-nbd.rules \
"
