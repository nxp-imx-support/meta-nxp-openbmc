# KERNEL_DEVICETREE is set in meta-latu-dcsm-imx95/conf/machine/latu-dcsm-imx95.conf

# conf/machine/include/nxp.inc (BMC_LINUX_SRC/_BRANCH/_SRCREV), which selects
# the internal Bitbucket mirror or the public GitHub tree from the single
# BMC_LINUX_USE_INTERNAL switch. No kernel patches are applied; this recipe
# only adds config fragments.

KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-mipi-4K-lt9611uxc.dtb"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../../recipes-kernel/linux/files:"

# Board config fragments on top of the shared OpenBMC ones.
SRC_URI:append:latu-dcsm-imx95 = " \
    file://openbmc_common.cfg \
    file://openbmc_imx943_imx95.cfg \
    file://latu-dcsm.cfg \
"
