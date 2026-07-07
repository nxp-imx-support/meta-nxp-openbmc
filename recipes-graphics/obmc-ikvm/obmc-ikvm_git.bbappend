FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://create_usbhid.sh"

do_install:append() {
    echo "Installing patched create_usbhid.sh from meta-nxp"

    install -m 0755 ${WORKDIR}/sources/create_usbhid.sh ${D}${bindir}/create_usbhid.sh
}
