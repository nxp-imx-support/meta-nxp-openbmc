# No platform-specific cfg - all config in openbmc_common.cfg
# KERNEL_DEVICETREE is set in meta-evb-imx95/conf/machine/evb-imx95.conf

# iKVM EP display DTBs - only for EVK with PCIe EP support
KERNEL_DEVICETREE:append:evb-imx95-evk = " freescale/${DTB_BASENAME}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:evb-imx95-evk = " freescale/${DTB_BASENAME}-ep-mipi-4K-lt9611uxc.dtb"

# NOR flash (fspi) kernel config and DTS patch for evb-imx95-evk-nor machine
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:evb-imx95-evk-nor = " file://nor-flexspi.cfg"

DEPENDS:append:latu-dcsm-imx95 = " u-boot-tools-native"

do_deploy:append:latu-dcsm-imx95() {
    ${STAGING_BINDIR_NATIVE}/mkimage \
        -A arm64 \
        -O linux \
        -T kernel \
        -C gzip \
        -a 0x80200000 \
        -e 0x80200000 \
        -n "Linux-Kernel-GZ" \
        -d ${DEPLOYDIR}/Image.gz \
        ${DEPLOYDIR}/uImage
}
KERNEL_DEVICETREE:append:evb-imx95-evk = " freescale/${DTB_BASENAME}-ep-no-display.dtb"
