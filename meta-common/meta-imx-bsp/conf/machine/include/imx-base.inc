# Provides the i.MX common settings

include conf/machine/include/fsl-default-settings.inc
include conf/machine/include/fsl-default-versions.inc

require conf/machine/include/utilities.inc

# Machines or distros can define which BSP it should use by default. We are
# intending to default for mainline BSP by default and specific machines or
# DISTROs might change it if need.
#
# Two values are considered valid: mainline, nxp
IMX_DEFAULT_BSP ?= "mainline"

# Those are SoC families we'd like to force the use of mainline BSP.
IMX_DEFAULT_BSP:mxs ?= "mainline"
IMX_DEFAULT_BSP:mx5 ?= "mainline"

MACHINEOVERRIDES =. "use-${IMX_DEFAULT_BSP}-bsp:"

# UBOOT_BINARY is used inside the wks files to dynamically find the required
# U-Boot file.
UBOOT_BINARY ?= "u-boot.${UBOOT_SUFFIX}"

# Using the 'IMX_DEFAULT_BOOTLOADER' the machine can support multiple bootloader
# versions. This is done for NXP reference board where we support 'u-boot-fslc'
# and 'u-boot-imx'.
#
# So, for example in imx6qdlsabresd, we support both flavor and for this we
# define:
#
# ,----[ imx6qdlsabresd.conf ]
# | ### u-boot-fslc settings ###
# |
# | SPL_BINARY:pn-u-boot-fslc = "SPL"
# | UBOOT_MACHINE:pn-u-boot-fslc ?= "mx6sabresd_defconfig"
# | UBOOT_SUFFIX:pn-u-boot-fslc = "img"
# |
# | ### u-boot-imx settings ###
# |
# | # The u-boot-imx does not provide unified functionality for DL/Q/QP SoC
# | # variants. Change the defconfig to the targeted SoC variant.
# | UBOOT_MACHINE:pn-u-boot-imx ?= "mx6qsabresd_defconfig"
# | UBOOT_SUFFIX:pn-u-boot-imx = "imx"
# `----
#
# As result, the 'UBOOT_SUFFIX' is dynamically set based on the preferred U-Boot
# flavor to use.
#
# For machines where one of the flavors is required, we can force it. An example
# is the imx53qsb, which we define:
#
# ,----[ imx53qsb.conf ]
# | # This machine is not supported by u-boot-imx as it is not tested by NXP on this
# | # board. So we force it to use u-boot-fslc which is based on mainline here.
# | IMX_DEFAULT_BOOTLOADER = "u-boot-fslc"
# |
# | UBOOT_MAKE_TARGET = "u-boot.imx"
# | UBOOT_SUFFIX = "imx"
# |
# | UBOOT_MACHINE = "mx53loco_config"
# `----
#
# Please note that UBOOT_SUFFIX must be set in the machine config even
# if the value is the same for the U-Boot flavors. If the value is not
# set, then the assignment here is the one used, the value resolves to
# empty, and the build fails:
# | cp: cannot stat '/.../tmp/work/imx8qm_mek-fsl-linux/u-boot-imx/2022.04-r0/build/imx8qm_mek_defconfig/u-boot.': No such file or directory
#| WARNING: /.../tmp/work/imx8qm_mek-fsl-linux/u-boot-imx/2022.04-r0/temp/run.do_compile.21223:186 exit 1 from 'cp /.../tmp/work/imx8qm_mek-fsl-linux/u-boot-imx/2022.04-r0/build/${config}/${binary} /.../tmp/work/imx8qm_mek-fsl-linux/u-boot-imx/2022.04-r0/build/${config}/u-boot-${type}.${UBOOT_SUFFIX:pn-u-boot-imx}'
#
IMX_DEFAULT_BOOTLOADER ??= "u-boot-fslc"
UBOOT_SUFFIX ?= "${UBOOT_SUFFIX:pn-${IMX_DEFAULT_BOOTLOADER}}"

# We need to export the original variable to allow it to be used when generating
# wic based images.
SPL_BINARY ??= "${@get_spl_binary(d)}"

PREFERRED_PROVIDER_u-boot ??= "${IMX_DEFAULT_BOOTLOADER}"
PREFERRED_PROVIDER_u-boot-mfgtool ??= "${IMX_DEFAULT_BOOTLOADER}"
PREFERRED_PROVIDER_virtual/bootloader ??= "${IMX_DEFAULT_BOOTLOADER}"

PREFERRED_PROVIDER_u-boot-mxsboot-native ??= "u-boot-fslc-mxsboot-native"

UBOOT_ENTRYPOINT:mxs-generic-bsp    ?= "0x40008000"
UBOOT_ENTRYPOINT:vf-generic-bsp     ?= "0x80008000"

# Some SoC can utilize the boot container provided by U-Boot,
# below variable sets that those SoC do use this rather than
# assembling it in the imx-boot recipe.
UBOOT_PROVIDES_BOOT_CONTAINER = "0"

# The boot container should be used only if we're not using u-boot-imx as
# IMX_DEFAULT_BOOTLOADER.
UBOOT_PROVIDES_BOOT_CONTAINER:mx8m-generic-bsp = "${@oe.utils.ifelse(d.getVar('IMX_DEFAULT_BOOTLOADER') == 'u-boot-imx', '0', '1')}"

# Trusted Firmware for Cortex-A (TF-A) can have different providers, either
# from upstream or from NXP downstream fork. Below variable defines which TF-A
# shall be taken into the build, and will be integrated into runtime image.
#
# Upstream TF-A recipe resides in the meta-arm layer and in maintained by OE
# community. Therefore, in order to add upstream TF-A - additional layer has
# to be included in the bblayers.con file. Compatible machines are added to
# this layer via dynamic-layers mechanism.
#
# NOTE: Current upstream TF-A version (v2.7) does not support HAB feature of
# i.MX8M family. If the upstream TF-A version is chosen, then HAB will not be
# available for all SoCs that are opting-in. This might change with future TF-A
# release, so this statement shall be kept here until support is added.
#
# Default TF-A provider to NXP downstream fork
IMX_DEFAULT_ATF_PROVIDER ??= "imx-atf"

# Allow setting the UART used during the boot by ATF.

SOC_ATF_BOOT_UART_BASE:mx8m-generic-bsp   = "0x30890000"
ATF_BOOT_UART_BASE                       ?= "${SOC_ATF_BOOT_UART_BASE}"

PREFERRED_PROVIDER_virtual/xserver      = "xserver-xorg"
XSERVER_DRIVER                          = "xf86-video-fbdev"
XSERVER_DRIVER:vf-generic-bsp           = "xf86-video-modesetting"
XSERVER_DRIVER:imx-mainline-bsp = " \
    xf86-video-fbdev \
    xf86-video-modesetting \
    xserver-xorg-extension-glx \
"
XSERVER = "xserver-xorg \
           xf86-input-evdev \
           ${XSERVER_DRIVER}"

# Ship kernel modules
MACHINE_EXTRA_RRECOMMENDS = "kernel-modules"

# Tunes for hard/soft float-point selection. Note that we allow building for
# thumb support giving distros the chance to enable thumb by setting
# ARM_INSTRUCTION_SET = "thumb"
#
# handled by software
# DEFAULTTUNE:mx6-generic-bsp ?= "cortexa9t-neon"
# handled by hardware
DEFAULTTUNE:vf-generic-bsp     ?= "cortexa5thf-neon"

DEFAULTTUNE:mx93-generic-bsp   ?= "cortexa55"

INHERIT += "machine-overrides-extender"

IMX_SOC_REV                    ??= "A0"
IMX_SOC_REV:mx93-generic-bsp   ??= "A1"

IMX_SOC_REV_LOWER   = "${@d.getVar('IMX_SOC_REV').lower()}"
IMX_SOC_REV_UPPER   = "${@d.getVar('IMX_SOC_REV').upper()}"

#######
### NXP BSP specific overrides
#######

MACHINEOVERRIDES_EXTENDER:mx93:use-nxp-bsp  = "imx-generic-bsp:imx-nxp-bsp:imxdrm:imxpxp:mx9-generic-bsp:mx9-nxp-bsp:mx93-generic-bsp:mx93-nxp-bsp"

#######
### Mainline BSP specific overrides
#######

MACHINEOVERRIDES_EXTENDER:vf:use-mainline-bsp     = "imx-generic-bsp:imx-mainline-bsp:vf-generic-bsp:vf-mainline-bsp"
MACHINEOVERRIDES_EXTENDER:mx93:use-mainline-bsp  = "imx-generic-bsp:imx-mainline-bsp:mx9-generic-bsp:mx9-mainline-bsp:mx93-generic-bsp:mx93-mainline-bsp"

MACHINEOVERRIDES_EXTENDER_FILTER_OUT = " \
    mx93 \
"

MACHINEOVERRIDES_FILTERED_OUT_QA_ERROR = "%s overrides cannot be used and need conversion to use the new BSP-specific overrides. Check 'meta-freescale/scripts/convert-bsp-specific-overrides'."

# Sub-architecture support
MACHINE_SOCARCH_SUFFIX ?= ""
MACHINE_SOCARCH_SUFFIX:mx93-nxp-bsp    = "-mx93"

# For Mainline we use a single SoC suffix as we don't have different build options
MACHINE_SOCARCH_SUFFIX:imx-mainline-bsp = "-imx"

MACHINE_ARCH_FILTER = "virtual/kernel"
MACHINE_SOCARCH_FILTER:append:imx-nxp-bsp = " \
    gstreamer1.0 \
    weston \
"
MACHINE_SOCARCH_FILTER:append:imxvpu = " \
    imx-codec \
    imx-vpuwrap \
    libimxvpuapi \
    virtual/imxvpu \
"
MACHINE_SOCARCH_FILTER:append:imx-mainline-bsp = " \
    virtual/egl \
    virtual/libopenvg \
    virtual/libg2d \
    virtual/libgl \
    virtual/libgles1 \
    virtual/libgles2 \
    virtual/mesa \
    cairo \
    pango \
    qtbase \
"
MACHINE_SOCARCH_FILTER:append:mx8qm-nxp-bsp = " \
    virtual/libopenvx \
"

INHERIT += "fsl-dynamic-packagearch"

SIGGEN_EXCLUDE_SAFE_RECIPE_DEPS:append = " \
    libimxvpuapi->virtual/imxvpu \
    imx-vpuwrap->virtual/imxvpu \
    imx-codec->virtual/imxvpu \
"

# Firmware used for boot.
IMX_EXTRA_FIRMWARE                   ?= ""
IMX_EXTRA_FIRMWARE:mx93-generic-bsp   = "imx-boot-firmware-files firmware-ele-imx"

# Firmware
MACHINE_FIRMWARE ?= ""
MACHINE_FIRMWARE:append:imx-mainline-bsp     = " linux-firmware-imx-sdma-imx6q linux-firmware-imx-sdma-imx7d firmware-imx-vpu-imx6q firmware-imx-vpu-imx6d"

MACHINE_EXTRA_RRECOMMENDS += "${MACHINE_FIRMWARE}"

# Extra udev rules
MACHINE_EXTRA_RRECOMMENDS += "udev-rules-imx"

# ELE extra Firmware
SECOEXT_FIRMWARE_NAME ?= "UNDEFINED"
SECOEXT_FIRMWARE_NAME:mx8ulp-generic-bsp ?= "mx8ulp${IMX_SOC_REV_LOWER}ext-ahab-container.img"

PREFERRED_VERSION_weston:imx-nxp-bsp      ??= "12.0.3.imx"
# i.MX 6 & 7 stay on weston 10.0 for fbdev
PREFERRED_VERSION_weston:imx-mainline-bsp   = ""

PREFERRED_VERSION_wayland-protocols:mx9-nxp-bsp  ??= "1.32.imx"

PREFERRED_VERSION_xwayland:imx-nxp-bsp ??= "23.1.1.imx"

# Use i.MX libdrm Version
PREFERRED_VERSION_libdrm:mx9-nxp-bsp ??= "2.4.116.imx"

# Use i.MX optee Version
PREFERRED_VERSION_optee-os:mx9-nxp-bsp     ??= "4.0.0.imx"
PREFERRED_VERSION_optee-client:mx9-nxp-bsp ??= "4.0.0.imx"
PREFERRED_VERSION_optee-test:mx9-nxp-bsp   ??= "4.0.0.imx"

# Use i.MX opencv Version
PREFERRED_VERSION_opencv:mx9-nxp-bsp ??= "4.6.0.imx"

# Handle default kernel
IMX_DEFAULT_KERNEL:imx-mainline-bsp = "linux-fslc"
IMX_DEFAULT_KERNEL:imx-nxp-bsp      = "linux-fslc-imx"

PREFERRED_PROVIDER_virtual/kernel ??= "${IMX_DEFAULT_KERNEL}"

SOC_DEFAULT_IMAGE_FSTYPES = "wic.bmap wic.gz"
SOC_DEFAULT_IMAGE_FSTYPES:mxs-generic-bsp = "uboot-mxsboot-sdcard wic.bmap wic.gz"

# Do not update fstab file when using wic images
WIC_CREATE_EXTRA_ARGS ?= "--no-fstab-update"

OPTEE_BIN_EXT ??= ""
OPTEE_BOOT_IMAGE         = "tee.bin uTee-${OPTEE_BIN_EXT}"
OPTEE_BOOT_IMAGE:mx9-generic-bsp = "tee.bin"

IMAGE_FSTYPES ?= "${SOC_DEFAULT_IMAGE_FSTYPES}"

IMAGE_BOOT_FILES ?= " \
    ${KERNEL_IMAGETYPE} \
    ${@make_dtb_boot_files(d)} \
    ${@bb.utils.contains('MACHINE_FEATURES', 'optee', '${OPTEE_BOOT_IMAGE}', '', d)} \
"

### wic default support
OPTEE_WKS_FILE_DEPENDS         = "optee-os"
OPTEE_WKS_FILE_DEPENDS:aarch64 = ""

WKS_FILE_DEPENDS ?= " \
    virtual/bootloader \
    \
    e2fsprogs-native \
    bmaptool-native \
    ${@bb.utils.contains('MACHINE_FEATURES', 'optee', '${OPTEE_WKS_FILE_DEPENDS}', '', d)} \
"

# We need to restrict the append so we don't add this for other i.MX SoC's.
# Derivatives that are not yet adopted the usage of boot container provided
# by U-Boot build are still targeted to use 'imx-boot' package provided by
# NXP.
#
# Moving those derivatives to mainline BSP would require to set
# UBOOT_PROVIDES_BOOT_CONTAINER to "1" and test if the U-Boot built 'flash.bin'
# binary is a working replacement.
#
# NOTE: the results binary name of the boot container is set to 'imx-boot'
# for both NXP and Mainline BSP.
WKS_FILE_DEPENDS:append:imx-generic-bsp:mx8-generic-bsp = " \
    ${@oe.utils.ifelse(d.getVar('UBOOT_PROVIDES_BOOT_CONTAINER') == '0', 'imx-boot', '')} \
"
WKS_FILE_DEPENDS:append:imx-generic-bsp:mx9-generic-bsp = " \
    ${@oe.utils.ifelse(d.getVar('UBOOT_PROVIDES_BOOT_CONTAINER') == '0', 'imx-boot', '')} \
"

SOC_DEFAULT_WKS_FILE ?= "imx-uboot-bootpart.wks.in"
SOC_DEFAULT_WKS_FILE:mxs-generic-bsp ?= "imx-uboot-mxs-bootpart.wks.in"
SOC_DEFAULT_WKS_FILE:mx9-generic-bsp ?= "imx-imx-boot-bootpart.wks.in"

WKS_FILE ?= "${SOC_DEFAULT_WKS_FILE}"

SERIAL_CONSOLES = "115200;ttymxc0"
SERIAL_CONSOLES:mxs-generic-bsp = "115200;ttyAMA0"

KERNEL_IMAGETYPE = "zImage"
KERNEL_IMAGETYPE:mx9-generic-bsp = "Image"

MACHINE_FEATURES = "usbgadget usbhost vfat touchscreen screen optee"

HOSTTOOLS_NONFATAL:append:mx8-nxp-bsp = " sha384sum"

# Add task to generate the mfgtool bundle for the image.
IMAGE_CLASSES:append:imx-generic-bsp = " image_populate_mfgtool"

# Allow meta-imx to add NIP devices information until upstreamed.
include conf/machine/include/imx-base-extend.inc
