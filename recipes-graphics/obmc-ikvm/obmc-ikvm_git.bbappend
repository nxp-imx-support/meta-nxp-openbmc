FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://create_usbhid.sh"

do_install:append() {
    echo "Installing patched create_usbhid.sh from meta-nxp"

    install -m 0755 ${WORKDIR}/sources/create_usbhid.sh ${D}${bindir}/create_usbhid.sh
}
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://create_usbhid.sh \
    file://load_kvm_modules.sh \
    file://99-obmc-ikvm.rules \
    file://start-obmc-ikvm.sh \
    file://override.conf \
    file://kvm.conf \
"

do_install:append() {
    echo "Installing custom obmc-ikvm files from meta-nxp"

    # Install patched USB HID creation script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/sources/create_usbhid.sh ${D}${bindir}/create_usbhid.sh

    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/sources/load_kvm_modules.sh ${D}${bindir}/load_kvm_modules.sh

    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/sources/99-obmc-ikvm.rules ${D}${sysconfdir}/udev/rules.d/

    # Install obmc-ikvm wrapper script
    install -m 0755 ${WORKDIR}/sources/start-obmc-ikvm.sh ${D}${bindir}/start-obmc-ikvm.sh

    # Install default KVM configuration
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/sources/kvm.conf ${D}${sysconfdir}/kvm.conf

    # Install systemd service override
    install -d ${D}${sysconfdir}/systemd/system/obmc-ikvm.service.d
    install -m 0644 ${WORKDIR}/sources/override.conf \
        ${D}${sysconfdir}/systemd/system/obmc-ikvm.service.d/override.conf
}

FILES:${PN} += " \
    ${bindir}/load_kvm_modules.sh \
    ${bindir}/start-obmc-ikvm.sh \
    ${sysconfdir}/kvm.conf \
    ${sysconfdir}/udev/rules.d/99-obmc-ikvm.rules \
    ${sysconfdir}/systemd/system/obmc-ikvm.service.d/override.conf \
"

