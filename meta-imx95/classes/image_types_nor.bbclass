# image_types_nor.bbclass
#
# Defines a custom "norflash" image type that produces a single flat binary
# suitable for writing directly to a SPI NOR flash device, analogous to the
# WIC image used for SD/eMMC.
#
# The output file is:
#   <image>-<machine>.norflash
#
# Write to NOR flash:
#   dd if=<image>-<machine>.norflash of=/dev/mtd0 bs=4096
#
# Or via U-Boot over TFTP:
#   tftp 0x80000000 obmc-phosphor-image-evb-imx95-nor.norflash
#   sf probe
#   sf erase 0 <NOR_FLASH_SIZE>
#   sf write 0x80000000 0 ${filesize}
#
# Partition layout (all values in bytes, must match machine conf, DTS, and
# U-Boot environment):
#
#   NOR_OFFSET_BOOT   = 0x00000000  flash.bin  (imx-boot container)
#   NOR_OFFSET_KERNEL = 0x00400000  Linux kernel Image
#   NOR_OFFSET_DTB    = 0x00C00000  Kernel DTB (.dtb)
#   NOR_OFFSET_ROOTFS = 0x00D00000  JFFS2 root filesystem
#   NOR_FLASH_SIZE    = 0x02000000  total NOR device size (32 MB default)
#
# Override any of these in your machine .conf if your hardware differs.

NOR_FLASH_SIZE    ?= "0x02000000"
NOR_OFFSET_BOOT   ?= "0x00000000"
NOR_OFFSET_KERNEL ?= "0x00400000"
NOR_OFFSET_DTB    ?= "0x00C00000"
NOR_OFFSET_ROOTFS ?= "0x00D00000"

# The norflash image type requires jffs2 to be built first
IMAGE_TYPEDEP:norflash = "jffs2"

do_image_norflash[depends] += " \
    imx-boot:do_deploy \
    virtual/kernel:do_deploy \
"

IMAGE_CMD:norflash() {
    local outfile="${IMGDEPLOYDIR}/${IMAGE_NAME}.norflash"
    local flash_size="${NOR_FLASH_SIZE}"
    local off_boot="${NOR_OFFSET_BOOT}"
    local off_kernel="${NOR_OFFSET_KERNEL}"
    local off_dtb="${NOR_OFFSET_DTB}"
    local off_rootfs="${NOR_OFFSET_ROOTFS}"

    # Resolve source files
    local boot_bin="${DEPLOY_DIR_IMAGE}/imx-boot"
    local kernel_img="${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}"
    local dtb_file="${DEPLOY_DIR_IMAGE}/${UBOOT_DTB_NAME}"
    local rootfs_jffs2="${IMGDEPLOYDIR}/${IMAGE_NAME}.jffs2"

    bbnote "norflash: creating flat NOR image: ${outfile}"
    bbnote "  flash size : ${flash_size}"
    bbnote "  boot  src  : ${boot_bin}   -> offset ${off_boot}"
    bbnote "  kernel src : ${kernel_img} -> offset ${off_kernel}"
    bbnote "  dtb   src  : ${dtb_file}   -> offset ${off_dtb}"
    bbnote "  rootfs src : ${rootfs_jffs2} -> offset ${off_rootfs}"

    # Validate inputs
    if [ ! -f "${boot_bin}" ]; then
        bbfatal "norflash: imx-boot (flash.bin) not found at ${boot_bin}"
    fi
    if [ ! -f "${kernel_img}" ]; then
        bbfatal "norflash: kernel image not found at ${kernel_img}"
    fi
    if [ ! -f "${dtb_file}" ]; then
        bbfatal "norflash: kernel DTB not found at ${dtb_file} (UBOOT_DTB_NAME=${UBOOT_DTB_NAME})"
    fi
    if [ ! -f "${rootfs_jffs2}" ]; then
        bbfatal "norflash: rootfs jffs2 not found at ${rootfs_jffs2}"
    fi

    # Helper: convert hex string (0xABCD) or decimal to decimal
    hex2dec() {
        printf "%d" "$1"
    }

    local flash_size_dec=$(hex2dec "${flash_size}")
    local off_boot_dec=$(hex2dec "${off_boot}")
    local off_kernel_dec=$(hex2dec "${off_kernel}")
    local off_dtb_dec=$(hex2dec "${off_dtb}")
    local off_rootfs_dec=$(hex2dec "${off_rootfs}")

    # Verify source sizes do not overflow partition boundaries
    local boot_size=$(stat -c%s "${boot_bin}")
    local kernel_size=$(stat -c%s "${kernel_img}")
    local dtb_size=$(stat -c%s "${dtb_file}")
    local rootfs_size=$(stat -c%s "${rootfs_jffs2}")

    bbnote "norflash: boot=${boot_size}B kernel=${kernel_size}B dtb=${dtb_size}B rootfs=${rootfs_size}B"

    if [ $(expr ${off_boot_dec} + ${boot_size}) -gt "${off_kernel_dec}" ]; then
        bbfatal "norflash: flash.bin (${boot_size} bytes) overflows into kernel partition at ${off_kernel}"
    fi
    if [ $(expr ${off_kernel_dec} + ${kernel_size}) -gt "${off_dtb_dec}" ]; then
        bbfatal "norflash: kernel (${kernel_size} bytes) overflows into DTB partition at ${off_dtb}"
    fi
    if [ $(expr ${off_dtb_dec} + ${dtb_size}) -gt "${off_rootfs_dec}" ]; then
        bbfatal "norflash: DTB (${dtb_size} bytes) overflows into rootfs partition at ${off_rootfs}"
    fi
    if [ $(expr ${off_rootfs_dec} + ${rootfs_size}) -gt "${flash_size_dec}" ]; then
        bbfatal "norflash: rootfs (${rootfs_size} bytes) overflows NOR flash end (size=${flash_size})"
    fi

    # Create a 0xFF-filled image matching NOR erased state.
    # 0xFF-filled regions: un-programmed NOR reads as 0xFF, which is
    # required so JFFS2 cleanmarker scanning of blank areas works correctly.
    python3 -c "
import sys
size = ${flash_size_dec}
sys.stdout.buffer.write(b'\\xff' * size)
" > "${outfile}"

    # Overlay flash.bin at boot offset
    dd if="${boot_bin}" of="${outfile}" bs=1 seek="${off_boot_dec}" conv=notrunc

    # Overlay kernel Image at kernel offset
    dd if="${kernel_img}" of="${outfile}" bs=1 seek="${off_kernel_dec}" conv=notrunc

    # Overlay kernel DTB at dtb offset
    dd if="${dtb_file}" of="${outfile}" bs=1 seek="${off_dtb_dec}" conv=notrunc

    # Overlay JFFS2 rootfs at rootfs offset
    dd if="${rootfs_jffs2}" of="${outfile}" bs=1 seek="${off_rootfs_dec}" conv=notrunc

    bbnote "norflash: image created: $(stat -c%s ${outfile}) bytes"

    # Create a convenience symlink without the timestamp
    local link="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.norflash"
    ln -sf "${IMAGE_NAME}.norflash" "${link}"
}

# Register the type with the image infrastructure
IMAGE_TYPES += "norflash"
