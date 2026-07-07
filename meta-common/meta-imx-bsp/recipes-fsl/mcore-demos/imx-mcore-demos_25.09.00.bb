# Copyright 2025-2026 NXP
# Released under the MIT license (see COPYING.MIT for the terms)

require imx-mcore-demos.inc

LIC_FILES_CHKSUM:mx943-nxp-bsp = "file://${WORKDIR}/imx943-mcore-demo-25.09.00/COPYING;md5=bc649096ad3928ec06a8713b8d787eac"

SRC_URI[imx943.sha256sum] = "ca18926237f4d2cdc0d560cb9613e07a945c80027ce7c98a0bff537448e4c1a7"

COMPATIBLE_MACHINE = "(mx943-nxp-bsp)"
S:mx943-nxp-bsp = "${UNPACKDIR}/imx943-mcore-demo-${PV}"

do_install:mx943-nxp-bsp () {
    install -d ${D}${nonarch_base_libdir}/firmware
    if ls ${WORKDIR}/imx943-mcore-demo-${PV}/*.elf > /dev/null 2>&1; then
        install -m 0644 ${WORKDIR}/imx943-mcore-demo-${PV}/*.elf ${D}${nonarch_base_libdir}/firmware
    fi
    install -m 0644 ${WORKDIR}/imx943-mcore-demo-${PV}/*.${MCORE_DEMO_FILE_EXTENSION} ${D}${nonarch_base_libdir}/firmware
}

do_deploy:mx943-nxp-bsp () {
    install -d ${DEPLOYDIR}/mcore-demos
    install -m 0644 ${WORKDIR}/imx943-mcore-demo-${PV}/*.${MCORE_DEMO_FILE_EXTENSION} ${DEPLOYDIR}/mcore-demos/
}
