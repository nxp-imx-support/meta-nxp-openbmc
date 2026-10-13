
LINUX_VERSION ?= "6.18.2"
LINUX_RPI_BRANCH ?= "rpi-6.18.y"
LINUX_RPI_KMETA_BRANCH ?= "yocto-6.18"

SRCREV_machine = "${BMC_LINUX_SRCREV}"
SRCREV_meta = "177495c151446a679945c20611499537d72ebcd9"

KERNEL_SRC = "${BMC_LINUX_SRC};branch=${BMC_LINUX_BRANCH}"
SRCBRANCH = "${BMC_LINUX_BRANCH}"
SRCREV = "${BMC_LINUX_SRCREV}"

PREFERRED_PROVIDER_virtual/kernel = "linux-nxp"

KMETA = "kernel-meta"

SRC_URI = " \
    ${KERNEL_SRC} \
    git://git.yoctoproject.org/yocto-kernel-cache;type=kmeta;name=meta;branch=${LINUX_RPI_KMETA_BRANCH};destsuffix=${KMETA} \
    "

require linux-nxp.inc

KERNEL_DTC_FLAGS += "-@ -H epapr"

# Use NXP upstream defconfig as base - OpenBMC delta applied via cfg fragments
KBUILD_DEFCONFIG = "imx_v8_defconfig"
KCONFIG_MODE = "--alldefconfig"

# --- Common OpenBMC kernel config fragment (all iMX9x platforms) ---
# Enables: MCTP, I2C_MUX, IMX_THERMAL, PINCTRL_IMX, WATCHDOG
# Disables: SQUASHFS_LZO (not needed for BMC)
OPENBMC_COMMON_CFG = "file://openbmc_common.cfg"

# --- iMX943/iMX95 additional config (not needed for iMX91/93) ---
# Enables: iKVM, DRM/DPU95, extra peripherals
# Disables: Layerscape/DPAA2 (not iMX9x SoCs), DVB tuners (not BMC)
OPENBMC_IMX943_IMX95_CFG = "file://openbmc_imx943_imx95.cfg"

# Downstream kernel patches are NOT applied by this recipe anymore.
#
# Both the internal NXP mirror branch (lf-6.18.y-bmc) and the public GitHub
# tree (nxp-qoriq/linux, branch lf-6.18.y-bmc) now carry every OpenBMC
# downstream change natively. Applying the old file://*.patch sets on top of
# either tree would double-apply and fail, so the patch lists are empty for
# both internal and external builds. The now-unused patch files have been
# removed from files/; only the *.cfg config fragments, which are the OpenBMC
# defconfig delta and are not in the kernel tree, remain and are added to
# SRC_URI below.

# Apply the OpenBMC config fragments via MACHINE override. No kernel patches.
SRC_URI:append:frdm-imx91     = " ${OPENBMC_COMMON_CFG}"
SRC_URI:append:frdm-imx93     = " ${OPENBMC_COMMON_CFG}"
SRC_URI:append:evb-imx943    = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG}"
SRC_URI:append:evb-imx943-am = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG}"
SRC_URI:append:frdm-imx95     = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG}"
SRC_URI:append:evb-imx95-evk = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG}"

