
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

SRC_URI:append:evb-imx91     = " ${IMX91_IMX93_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx93     = " ${IMX91_IMX93_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943    = " ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx943-am = " ${IMX943_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95     = " ${IMX95_PATCHES} ${BSP_FIXES}"
SRC_URI:append:evb-imx95-evk = " ${IMX95_PATCHES} ${BSP_FIXES}"

SRC_URI:append:mx943-nxp-bsp = " ${IKVM_PCIE_EP_PATCHES}"
SRC_URI:append:mx95-nxp-bsp  = " ${IKVM_PCIE_EP_PATCHES}"

