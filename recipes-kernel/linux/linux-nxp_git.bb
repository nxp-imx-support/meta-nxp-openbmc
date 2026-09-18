
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

# When building from the internal NXP kernel mirror (BMC_LINUX_USE_INTERNAL=1,
# set in conf/machine/include/nxp.inc) the branch already contains all of the
# downstream patches below, so none of the file://*.patch sets are applied.
# Only the *.cfg config fragments are added to SRC_URI in that case.
# When building from the public GitHub tree the patches are applied as usual.

# imx91 / imx93 common patches
IMX91_IMX93_PATCHES = "${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', '', ' \
    file://0005-openbmc-imx91-imx93-support.patch \
    file://0006-P3T2030-temperature-sensor-imx93.patch \
    file://0007-imx93-usb-peripheral-mode.patch \
', d)}"

# imx943 patches
IMX943_PATCHES = "${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', '', ' \
    file://0008-imx943-local-display.patch \
    file://0009-imx943-antmicro-dc-scm-dts.patch \
', d)}"

# imx95 patches
IMX95_PATCHES = "${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', '', ' \
    file://0010-openbmc-imx95-frdm-support.patch \
', d)}"

# BSP kernel bug fixes (all platforms)
BSP_FIXES = "${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', '', ' \
    file://0011-media-ox05b1s-fix-variable-declaration-after-label.patch \
', d)}"

# iKVM PCIe EP patches (mx943 and mx95 only)
IKVM_PCIE_EP_PATCHES = "${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', '', ' \
    file://0004-ikvm-pcie-ep-local-display-remote-kvm-imx95-6.18.patch \
    file://0012-media-stream2v4l2-fix-vb2-release-and-resolution-upd.patch \
    file://0013-media-stream2v4l2-use-DPU95-blit-engine-for-zero-cop.patch \
    file://0014-meta-nxp-media-stream2v4l2-add-i.MX94-support-and-fi.patch \
    file://0015-PCI-endpoint-add-alloc_bar-free_bar-ops-to-pci_epf_o.patch \
    file://0016-PCI-endpoint-core-restore-generic-BAR-alloc-remove-V.patch \
    file://0017-PCI-endpoint-add-pci-epf-imx9-vga-driver-for-i.MX9-i.patch \
    file://0018-PCI-endpoint-Kconfig-Makefile-add-PCI_EPF_IMX9_VGA-e.patch \
    file://0019-PCI-endpoint-Add-iKVM-HID-input-support-to-i.MX9-VGA.patch \
    file://0020-PCI-endpoint-Add-configurable-iKVM-display-and-KVM-m.patch \
    file://0021-arm64-dts-imx95-Add-no-display-DPU-overlay-for-PCIe-.patch \
', d)}"


# Apply common cfg + per-platform patches via MACHINE override
SRC_URI:append:evb-imx91     = " ${OPENBMC_COMMON_CFG} ${IMX91_IMX93_PATCHES} ${IMX91_BMC_DTS_INTERNAL} ${BSP_FIXES}"
SRC_URI:append:evb-imx93     = " ${OPENBMC_COMMON_CFG} ${IMX91_IMX93_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943    = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943-am = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95     = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX95_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95-evk = " ${OPENBMC_COMMON_CFG} ${OPENBMC_IMX943_IMX95_CFG} ${IMX95_PATCHES} ${BSP_FIXES}"

SRC_URI:append:mx943-nxp-bsp = " ${IKVM_PCIE_EP_PATCHES}"
SRC_URI:append:mx95-nxp-bsp  = " ${IKVM_PCIE_EP_PATCHES}"

