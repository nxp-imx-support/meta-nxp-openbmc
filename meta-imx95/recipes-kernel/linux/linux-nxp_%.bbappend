require conf/machine/include/imx95.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-openbmc-add-support-for-imx95-frdm.patch"
SRC_URI += "file://imx_openbmc_defconfig"

S = "${WORKDIR}/git"

SRC_URI += "file://disable-console_fb.cfg"
KERNEL_CONFIG_FRAGMENTS += "disable-console_fb.cfg"

# Copy defconfig into kernel source before metadata check
do_kernel_metadata:prepend() {
    cp ${UNPACKDIR}/imx_openbmc_defconfig ${S}/arch/arm64/configs/
}

KERNEL_DEVICETREE:append = " freescale/imx95-15x15-frdm-bmc.dtb"
KERNEL_DEVICETREE:append = " freescale/imx95-19x19-evk-ep-adv7535.dtb"
KERNEL_DEVICETREE:append = " freescale/imx95-19x19-evk-ep-mipi-4K-lt9611uxc.dtb"
