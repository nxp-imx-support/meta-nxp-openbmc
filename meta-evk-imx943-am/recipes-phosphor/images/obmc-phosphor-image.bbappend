# Enable the norflash image type for evk-imx943-am.
# Produces a single flat binary containing all NOR components:
#   boot   (offset 0x00000000): imx-boot-evk-imx943-am-xspi.bin-flash_a55_xspi
#   kernel (offset 0x002E0000): Image (Linux kernel)
#   dtb    (offset 0x025E0000): imx943-dc-scm.dtb
#   rootfs (offset 0x02600000): obmc-phosphor-image-evk-imx943-am.jffs2
#
# Output: obmc-phosphor-image-evk-imx943-am-<timestamp>.norflash (~98 MB)
# Symlink: obmc-phosphor-image-evk-imx943-am.norflash
#
# Flash via dd:
#   dd if=obmc-phosphor-image-evk-imx943-am.norflash of=/dev/mtd0 bs=4096
# Flash via U-Boot sf write:
#   sf probe; sf erase 0 0x6200000; sf write ${loadaddr} 0 ${filesize}

inherit image_types_nor

IMAGE_FSTYPES:append:evk-imx943-am = " jffs2 norflash wic wic.bz2"
EXTRA_IMAGECMD:jffs2:evk-imx943-am = "--pad --no-cleanmarkers --eraseblock=0x10000"

# Deploy the UUU (Universal Update Utility) script for NOR flashing via USB
UUU_SCRIPT_DIR := "${THISDIR}/files"

deploy_uuu_script() {
    install -m 0644 ${UUU_SCRIPT_DIR}/flash_nor_uuu.auto ${IMGDEPLOYDIR}/flash_nor_uuu.auto
    install -m 0644 ${UUU_SCRIPT_DIR}/Readme_nor_flash.md ${IMGDEPLOYDIR}/Readme_nor_flash.md
}

IMAGE_POSTPROCESS_COMMAND:append:evk-imx943-am = " deploy_uuu_script;"
