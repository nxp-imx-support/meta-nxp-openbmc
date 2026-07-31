FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://create_usbhid.sh"
SRC_URI += "file://start_ikvm.sh"

do_install:append() {
    echo "Installing patched create_usbhid.sh from meta-nxp"
    install -m 0755 ${WORKDIR}/sources/create_usbhid.sh ${D}${bindir}/create_usbhid.sh

    echo "Installing start_ikvm.sh from meta-nxp"
    install -m 0755 ${WORKDIR}/sources/start_ikvm.sh ${D}${bindir}/start_ikvm.sh
}

FILES:${PN} += " ${bindir}/start_ikvm.sh"
