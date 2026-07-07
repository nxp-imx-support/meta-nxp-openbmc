# No platform-specific cfg - all config in openbmc_common.cfg
# KERNEL_DEVICETREE is set in meta-evb-imx95-evk/conf/machine/evb-imx95-evk.conf

# iKVM EP display DTBs - only for EVK with PCIe EP support
KERNEL_DEVICETREE:append:mx95-nxp-bsp = " freescale/${DTB_BASENAME}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:mx95-nxp-bsp = " freescale/${DTB_BASENAME}-ep-mipi-4K-lt9611uxc.dtb"
