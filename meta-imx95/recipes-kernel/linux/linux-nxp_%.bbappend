require conf/machine/include/imx95.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-openbmc-add-support-for-imx95-frdm.patch"
SRC_URI += "file://imx_openbmc_defconfig"

S = "${WORKDIR}/git"

# Copy defconfig into kernel source before metadata check
do_kernel_metadata:prepend() {
    cp ${UNPACKDIR}/imx_openbmc_defconfig ${S}/arch/arm64/configs/
}

KERNEL_DEVICETREE:append = " freescale/imx95-15x15-frdm-bmc.dtb"
