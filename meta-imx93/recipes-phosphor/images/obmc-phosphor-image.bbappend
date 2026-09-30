IMAGE_INSTALL:append = " bmc-init"

IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'fpga-sim qspi-mailbox obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:remove = " packagegroup-fsl-optee-imx "

OBMC_WEBUI = "webui-vue"
OBMC_IMAGE_EXTRA_INSTALL:append:nxp = " webui-vue phosphor-image-signing"

# -----------------------------------------------------------------
# NOR flash image overrides for evb-imx93-nor machine
#
# For NOR flash boot the rootfs must be JFFS2. In addition we produce
# a "norflash" consolidated image that concatenates flash.bin + kernel
# Image + JFFS2 rootfs into a single flat binary at the correct NOR
# offsets, ready to program with dd or U-Boot sf.
# -----------------------------------------------------------------

# Inherit the custom NOR image type class (defines IMAGE_CMD:norflash)
inherit image_types_nor

# Build both the raw JFFS2 rootfs and the consolidated norflash image.
# JFFS2 erase block size: 0x10000 = 64 KB (kernel uses 64 KB erase blocks
# since CONFIG_MTD_SPI_NOR_USE_4K_SECTORS is disabled in nor-flexspi.cfg).
# --no-cleanmarkers: NOR flash does not use NAND-style cleanmarkers.
# --pad: pad output to a full erase block boundary.
IMAGE_FSTYPES:evb-imx93-nor = "jffs2 norflash"
EXTRA_IMAGECMD:jffs2:evb-imx93-nor = "--pad --no-cleanmarkers --eraseblock=0x10000"

# Pull in NOR size-reduction only when the 'nor-size-reduction' feature is set.
# Debug builds leave it unset to keep all debug/diagnostic tools.
require ${@bb.utils.contains('DISTRO_FEATURES', 'nor-size-reduction', \
        'recipes-phosphor/images/obmc-phosphor-image-size-reduction.inc', \
        '', d)}
