FILESEXTRAPATHS:prepend := "${THISDIR}/obmc-ikvm:"

SRC_URI:append:evb-imx943 = " file://evb-imx943/override.conf"

do_install:append:evb-imx943() {
    install -d ${D}${systemd_system_unitdir}/obmc-ikvm.service.d
    install -m 0644 ${WORKDIR}/sources/evb-imx943/override.conf \
        ${D}${systemd_system_unitdir}/obmc-ikvm.service.d/override.conf
}

FILES:${PN}:append:evb-imx943 = " ${systemd_system_unitdir}/obmc-ikvm.service.d/override.conf"
