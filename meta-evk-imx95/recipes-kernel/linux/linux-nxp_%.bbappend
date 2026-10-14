# No platform-specific cfg - all config in openbmc_common.cfg
# KERNEL_DEVICETREE is set in meta-evk-imx95/conf/machine/evk-imx95.conf

# iKVM EP display DTBs - only for EVK with PCIe EP support
KERNEL_DEVICETREE:append:mx95-nxp-bsp = " freescale/${DTB_BASENAME}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:mx95-nxp-bsp = " freescale/${DTB_BASENAME}-ep-mipi-4K-lt9611uxc.dtb"
KERNEL_DEVICETREE:append:mx95-nxp-bsp = " freescale/${DTB_BASENAME}-ep-no-display.dtb"
