# This file is included from meta-freescale/conf/machine/include/imx-base.inc
# and provides a simple mechanism to override settings in the file

IMX_DEFAULT_BSP = "nxp"

# The default kernel set in meta-freescale is for fslc
IMX_DEFAULT_KERNEL:imx-nxp-bsp     = "linux-imx"

# IMXBOOT_VARIANT infrastructure
IMXBOOT_VARIANT  ?= ""
IMXBOOT_VARIANTS ?= "NONE"
BOOT_VARIANT = "${@bb.utils.contains_any('IMXBOOT_VARIANT', '${IMXBOOT_VARIANTS}', '-variant-${IMXBOOT_VARIANT}', '', d)}"

# Add DDR firmware dependency for mx91 and mx93
IMX_EXTRA_FIRMWARE:mx91-nxp-bsp = "imx-boot-firmware-files firmware-ele-imx"
IMX_EXTRA_FIRMWARE:mx93-nxp-bsp = "imx-boot-firmware-files firmware-ele-imx"

# Add new SoC i.MX 943
MACHINEOVERRIDES_EXTENDER:mx943:use-nxp-bsp  = "imx-generic-bsp:imx-nxp-bsp:imxdrm:imxpxp:mx9-generic-bsp:mx9-nxp-bsp:mx94-generic-bsp:mx94-nxp-bsp:mx943-generic-bsp:mx943-nxp-bsp"
MACHINE_SOCARCH_SUFFIX:mx943-nxp-bsp = "-mx943"
IMX_EXTRA_FIRMWARE:mx943-nxp-bsp = "imx-boot-firmware-files firmware-ele-imx ${SYSTEM_MANAGER_RPROVIDER} imx-oei"
SECO_FIRMWARE_NAME:mx943-generic-bsp ?= "mx943${IMX_SOC_REV_LOWER}-ahab-container.img"
PREFERRED_PROVIDER_virtual/libg2d:mx943-nxp-bsp ?= "imx-pxp-g2d"

# Update i.MX 95
IMX_SOC_REV:mx95-generic-bsp ?= "B0"
IMX_EXTRA_FIRMWARE:mx95-nxp-bsp = "imx-boot-firmware-files firmware-ele-imx ${SYSTEM_MANAGER_RPROVIDER} imx-oei"
SYSTEM_MANAGER_RPROVIDER ?= "imx-system-manager"
# The System Manager Firmware Name corresponds to a particular binary implementation
# in the Yocto deploy folder. The default name is comprised of the Firmware Basename
# and the default system manager Config name, e.g., m33_image-mx95evk.bin and
# m33_image-mx95evk_fusa.bin for the standard BSP version and FuSa version, respectively
SYSTEM_MANAGER_FIRMWARE_NAME                  ?= "${SYSTEM_MANAGER_FIRMWARE_BASENAME}-${SYSTEM_MANAGER_CONFIG}"
# The System Manager Firmware Basename is an alias used by imx-boot instead of using
# a unique name for each implementation, e.g., m33_image.bin for i.MX 95
SYSTEM_MANAGER_FIRMWARE_BASENAME              ?= "INVALID"
SYSTEM_MANAGER_FIRMWARE_BASENAME:mx95-nxp-bsp ?= "m33_image"
SYSTEM_MANAGER_FIRMWARE_BASENAME:mx943-nxp-bsp ?= "m33_image"

# ELE extra/runtime firmware, to be installed and accessed from userspace.
# Note that multiple names can be given in order to install multiple versions
# to a single rootfs.
SECOEXT_FIRMWARE_NAME                     = ""
SECOEXT_FIRMWARE_NAME:mx95-generic-bsp   ?= "mx95a0runtime-ahab-container.img mx95b0runtime-ahab-container.img"
SECOEXT_FIRMWARE_NAME:mx943-generic-bsp  ?= "mx943${IMX_SOC_REV_LOWER}runtime-ahab-container.img"

PREFERRED_VERSION_ffmpeg:mx9-nxp-bsp ??= "7.1.1"

PREFERRED_VERSION_weston:imx-nxp-bsp ??= "14.0.2.imx"

PREFERRED_VERSION_wayland-protocols:imx-nxp-bsp ??= "1.41.imx"

PREFERRED_VERSION_xwayland:imx-nxp-bsp ??= ""

PREFERRED_VERSION_libdrm:imx-nxp-bsp ??= "2.4.123.imx"

PREFERRED_VERSION_optee-client:mx9-nxp-bsp ??= "4.6.0.imx"
PREFERRED_VERSION_optee-os:mx9-nxp-bsp     ??= "4.6.0.imx"
PREFERRED_VERSION_optee-test:mx9-nxp-bsp   ??= "4.6.0.imx"
PREFERRED_VERSION_optee-os-tadevkit:mx9-nxp-bsp   ??= "4.6.0.imx"
SOC_DEFAULT_IMAGE_FSTYPES = "wic.bmap wic.zst tar.zst"
ZSTD_COMPRESSION_LEVEL ?= "10"
