FILESEXTRAPATHS:prepend := "${THISDIR}/obmc-ikvm:"

SRC_URI:append:evb-imx95-evk = " file://evb-imx95-evk/override.conf"

do_install:append:evb-imx95-evk() {
    install -d ${D}${systemd_system_unitdir}/obmc-ikvm.service.d
    install -m 0644 ${WORKDIR}/sources/evb-imx95-evk/override.conf \
        ${D}${systemd_system_unitdir}/obmc-ikvm.service.d/override.conf
}

FILES:${PN}:append:evb-imx95-evk = " ${systemd_system_unitdir}/obmc-ikvm.service.d/override.conf"
