
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

# imx91 / imx93 common patches
IMX91_IMX93_PATCHES = " \
    file://0005-openbmc-imx91-imx93-support.patch \
    file://0006-P3T2030-temperature-sensor-imx93.patch \
    file://0007-imx93-usb-peripheral-mode.patch \
"

# imx943 patches
IMX943_PATCHES = " \
    file://0008-imx943-local-display.patch \
    file://0009-imx943-antmicro-dc-scm-dts.patch \
"

# imx95 patches
IMX95_PATCHES = " \
    file://0010-openbmc-imx95-frdm-support.patch \
"

# BSP kernel bug fixes (all platforms)
BSP_FIXES = " \
    file://0011-media-ox05b1s-fix-variable-declaration-after-label.patch \
"

# iKVM PCIe EP patches (mx943 and mx95 only)
IKVM_PCIE_EP_PATCHES = " \
    file://0004-ikvm-pcie-ep-local-display-remote-kvm-imx95-6.18.patch \
"

# Apply common cfg + per-platform patches via MACHINE override
SRC_URI:append:evb-imx91     = " ${OPENBMC_COMMON_CFG} ${IMX91_IMX93_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx93     = " ${OPENBMC_COMMON_CFG} ${IMX91_IMX93_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943    = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943-am = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95     = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX95_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95-evk = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX95_PATCHES} ${BSP_FIXES}"

SRC_URI:append:mx943-nxp-bsp = " ${IKVM_PCIE_EP_PATCHES}"
SRC_URI:append:mx95-nxp-bsp  = " ${IKVM_PCIE_EP_PATCHES}"

