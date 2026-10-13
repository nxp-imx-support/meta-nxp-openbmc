# Override kernel source repository and branch for latu-dcsm-imx95
# KERNEL_DEVICETREE is set in meta-latu-dcsm-imx95/conf/machine/latu-dcsm-imx95.conf

# latu-dcsm uses a dedicated linux-imx fork with board-specific DTS and drivers.
# The branch lf-6.18.y_latu_dcsm contains all board-specific changes; no extra
# patches or config fragments from the shared meta-nxp recipes are applied.
LATU_DCSM_LINUX_SRC = "git://git@bitbucket.sw.nxp.com/isp/linux-imx.git;protocol=ssh"
LATU_DCSM_LINUX_BRANCH = "lf-6.18.y_latu_dcsm"

# TODO: update SRCREV to the desired commit SHA on branch lf-6.18.y_latu_dcsm
LATU_DCSM_LINUX_SRCREV = "${AUTOREV}"

KERNEL_SRC:latu-dcsm-imx95     = "${LATU_DCSM_LINUX_SRC};branch=${LATU_DCSM_LINUX_BRANCH}"
SRCBRANCH:latu-dcsm-imx95      = "${LATU_DCSM_LINUX_BRANCH}"
SRCREV_machine:latu-dcsm-imx95 = "${LATU_DCSM_LINUX_SRCREV}"
SRCREV:latu-dcsm-imx95         = "${LATU_DCSM_LINUX_SRCREV}"

KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-mipi-4K-lt9611uxc.dtb"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../../recipes-kernel/linux/files:"

# No kernel patches are applied by the shared linux-nxp recipe anymore (both
# the internal and public GitHub trees carry the downstream changes natively),
# so there is nothing to SRC_URI:remove here. The latu-dcsm branch likewise
# carries all its board-specific changes; this recipe only adds config
# fragments.
SRC_URI:append:latu-dcsm-imx95 = " \
    file://openbmc_common.cfg \
    file://openbmc_imx943_imx95.cfg \
    file://latu-dcsm.cfg \
"
