# Enable the norflash image type for latu-dcsm-imx95.
# Produces a single flat binary containing all 4 NOR components:
#   boot   (offset 0x0000000): imx-boot-latu-dcsm-imx95-fspi.bin-flash_a55_flexspi
#   kernel (offset 0x002E0000): Image.gz (Linux kernel)
#   dtb_0  (offset 0x1120000): imx95-19x19-latu-dcsm-it6251-lvds0.dtb
#   dtb_1  (offset 0x1140000): imx95-19x19-latu-dcsm.dtb
#   dtb_2  (offset 0x1160000): imx95-19x19-evk-ep-adv7535.dtb
#   dtb_3  (offset 0x1180000): imx95-19x19-evk-ep-mipi-4K-lt9611uxc.dtb
#   rootfs (offset 0x11A0000): obmc-phosphor-image-latu-dcsm-imx95.jffs2
#
# Output: obmc-phosphor-image-latu-dcsm-imx95-<timestamp>.norflash (~59 MB)
# Symlink: obmc-phosphor-image-latu-dcsm-imx95.norflash
#
# Production (trimmed, 40.5 MB rootfs partition):
#   DISTRO_FEATURES contains 'nor-size-reduction' (default in machine conf)
#
# Debug (full tools, all packages kept):
#   DISTRO_FEATURES:remove = "nor-size-reduction"   (in local.conf)
#
# Flash via dd:
#   dd if=obmc-phosphor-image-latu-dcsm-imx95.norflash of=/dev/mtd0 bs=4096
# Flash via U-Boot sf write:
#   sf probe; sf erase 0 0x03A20000; sf write ${loadaddr} 0 ${filesize}

inherit image_types_nor

IMAGE_FSTYPES:append:latu-dcsm-imx95 = " jffs2 norflash wic wic.bz2"
EXTRA_IMAGECMD:jffs2:latu-dcsm-imx95 = "--pad --no-cleanmarkers --eraseblock=0x10000"

# Deploy the UUU (Universal Update Utility) script for NOR flashing via USB
UUU_SCRIPT_DIR := "${THISDIR}/files"

deploy_uuu_script() {
    install -m 0644 ${UUU_SCRIPT_DIR}/flash_nor_uuu.auto ${IMGDEPLOYDIR}/flash_nor_uuu.auto
    install -m 0644 ${UUU_SCRIPT_DIR}/Readme_nor_flash.md ${IMGDEPLOYDIR}/Readme_nor_flash.md
}

IMAGE_POSTPROCESS_COMMAND:append:latu-dcsm-imx95 = " deploy_uuu_script;"

# Kernel modules must be explicitly installed for NOR/jffs2 rootfs.
# MACHINE_EXTRA_RRECOMMENDS is not sufficient for constrained NOR images.
IMAGE_INSTALL:append:latu-dcsm-imx95 = " \
    kernel-module-gpio-imx-flexio-sgpio \
    kernel-module-jtag-imx-flexio \
    kernel-module-pci-epf-imx9-vga \
    kernel-module-stream2v4l2 \
    kernel-module-imx9-qspi-mailbox \
"

# Pull in NOR size-reduction only when the 'nor-size-reduction' feature is set.
# Debug builds leave it unset to keep all debug/diagnostic tools.
require ${@bb.utils.contains('DISTRO_FEATURES', 'nor-size-reduction', \
        'recipes-phosphor/images/obmc-phosphor-image-size-reduction.inc', \
        '', d)}
