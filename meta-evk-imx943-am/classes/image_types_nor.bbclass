# image_types_nor.bbclass
#
# Defines a custom "norflash" image type that produces a single flat binary
# suitable for writing directly to a SPI NOR flash device.
#
# The output file is:
#   <image>-<machine>.norflash
#
# Write to NOR flash via Linux:
#   dd if=<image>-<machine>.norflash of=/dev/mtd0 bs=4096
#
# Or via U-Boot over TFTP:
#   tftp 0x80000000 obmc-phosphor-image-evk-imx943-am.norflash
#   sf probe
#   sf erase 0 <NOR_FLASH_SIZE>
#   sf write 0x80000000 0 ${filesize}
#
# Partition layout (all values in bytes, must match machine conf, DTS, and
# U-Boot environment):
#
#   NOR_OFFSET_BOOT   = 0x00000000  imx-boot container (flash.bin)
#   NOR_OFFSET_KERNEL = 0x002E0000  Linux kernel Image
#   NOR_OFFSET_DTB_0  = 0x025E0000  DTB slot 0 (default boot DTB)
#   NOR_OFFSET_DTB_1  = 0x025E0000  DTB slot 1
#   NOR_OFFSET_DTB_2  = 0x025E0000  DTB slot 2
#   NOR_OFFSET_DTB_3  = 0x025E0000  DTB slot 3
#   NOR_OFFSET_ROOTFS = 0x02600000  JFFS2 root filesystem
#   NOR_FLASH_SIZE    = 0x06200000  total NOR device size (~98 MB)
#
# Each DTB slot is NOR_DTB_SLOT_SIZE bytes (default 0x20000 = 128 KB).
# NOR_DTB_[n]_NAME sets which built DTB file goes into slot n.
# U-Boot selects the active slot at runtime via the dtb_sel env variable.
#
# Override any of these in the machine .conf to match your hardware.

NOR_FLASH_SIZE    ?= "0x06200000"
NOR_OFFSET_BOOT   ?= "0x00000000"
NOR_OFFSET_KERNEL ?= "0x002E0000"
NOR_OFFSET_ROOTFS ?= "0x02600000"

NOR_OFFSET_DTB_0  ?= "0x025E0000"
NOR_OFFSET_DTB_1  ?= "0x025E0000"
NOR_OFFSET_DTB_2  ?= "0x025E0000"
NOR_OFFSET_DTB_3  ?= "0x025E0000"
NOR_DTB_SLOT_SIZE ?= "0x20000"

# NOR_DTB_[n]_NAME: DTB file name (basename only) for each slot.
# Slot 0 is the default boot DTB (loaded when dtb_sel=0 in U-Boot env).
# Override all four in the machine .conf.
NOR_DTB_0_NAME ?= "${UBOOT_DTB_NAME}"
NOR_DTB_1_NAME ?= "${UBOOT_DTB_NAME}"
NOR_DTB_2_NAME ?= "${UBOOT_DTB_NAME}"
NOR_DTB_3_NAME ?= "${UBOOT_DTB_NAME}"
NOR_BOOT_BIN          ?= "${DEPLOY_DIR_IMAGE}/imx-boot"
NOR_KERNEL_IMAGETYPE  ?= "${KERNEL_IMAGETYPE}"

# norflash requires jffs2 to be built first
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
    local off_dtb_0="${NOR_OFFSET_DTB_0}"
    local off_dtb_1="${NOR_OFFSET_DTB_1}"
    local off_dtb_2="${NOR_OFFSET_DTB_2}"
    local off_dtb_3="${NOR_OFFSET_DTB_3}"
    local off_rootfs="${NOR_OFFSET_ROOTFS}"
    local slot_size="${NOR_DTB_SLOT_SIZE}"

    # Resolve source files
    local boot_bin="${NOR_BOOT_BIN}"
    local kernel_img="${DEPLOY_DIR_IMAGE}/${NOR_KERNEL_IMAGETYPE}"
    local dtb_0="${DEPLOY_DIR_IMAGE}/${NOR_DTB_0_NAME}"
    local dtb_1="${DEPLOY_DIR_IMAGE}/${NOR_DTB_1_NAME}"
    local dtb_2="${DEPLOY_DIR_IMAGE}/${NOR_DTB_2_NAME}"
    local dtb_3="${DEPLOY_DIR_IMAGE}/${NOR_DTB_3_NAME}"
    local rootfs_jffs2="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.jffs2"

    bbnote "norflash: creating flat NOR image: ${outfile}"
    bbnote "  flash size : ${flash_size}"
    bbnote "  boot  src  : ${boot_bin}     -> offset ${off_boot}"
    bbnote "  kernel src : ${kernel_img}   -> offset ${off_kernel}"
    bbnote "  dtb slot 0 : ${dtb_0}        -> offset ${off_dtb_0} (${NOR_DTB_0_NAME})"
    bbnote "  dtb slot 1 : ${dtb_1}        -> offset ${off_dtb_1} (${NOR_DTB_1_NAME})"
    bbnote "  dtb slot 2 : ${dtb_2}        -> offset ${off_dtb_2} (${NOR_DTB_2_NAME})"
    bbnote "  dtb slot 3 : ${dtb_3}        -> offset ${off_dtb_3} (${NOR_DTB_3_NAME})"
    bbnote "  rootfs src : ${rootfs_jffs2} -> offset ${off_rootfs}"

    # Validate inputs
    if [ ! -f "${boot_bin}" ]; then
        bbfatal "norflash: imx-boot not found at ${boot_bin}"
    fi
    if [ ! -f "${kernel_img}" ]; then
        bbfatal "norflash: kernel image not found at ${kernel_img}"
    fi
    if [ ! -f "${dtb_0}" ]; then
        bbfatal "norflash: DTB not found at ${dtb_0} (NOR_DTB_NAME=${NOR_DTB_0_NAME})"
    fi
    if [ ! -f "${dtb_1}" ]; then
        bbfatal "norflash: DTB not found at ${dtb_1} (NOR_DTB_NAME=${NOR_DTB_1_NAME})"
    fi
    if [ ! -f "${dtb_2}" ]; then
        bbfatal "norflash: DTB not found at ${dtb_2} (NOR_DTB_NAME=${NOR_DTB_2_NAME})"
    fi
    if [ ! -f "${dtb_3}" ]; then
        bbfatal "norflash: DTB not found at ${dtb_3} (NOR_DTB_NAME=${NOR_DTB_3_NAME})"
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
    local off_dtb0_dec=$(hex2dec "${off_dtb_0}")
    local off_dtb1_dec=$(hex2dec "${off_dtb_1}")
    local off_dtb2_dec=$(hex2dec "${off_dtb_2}")
    local off_dtb3_dec=$(hex2dec "${off_dtb_3}")
    local off_rootfs_dec=$(hex2dec "${off_rootfs}")
    local slot_size_dec=$(hex2dec "${slot_size}")

    # Verify source sizes do not overflow partition boundaries
    for i in 0 1 2 3; do
        eval local dtb_f="\${dtb_${i}}"
        eval local dtb_off_dec="\${off_dtb${i}_dec}"
        local dtb_sz=$(stat -c%s "${dtb_f}")
        if [ "${dtb_sz}" -gt "${slot_size_dec}" ]; then
            bbfatal "norflash: DTB slot ${i} (${dtb_sz} bytes) exceeds slot size (${slot_size})"
        fi
    done

    local boot_size=$(stat -c%s "${boot_bin}")
    local kernel_size=$(stat -c%s "${kernel_img}")
    local rootfs_size=$(stat -c%s "${rootfs_jffs2}")

    if [ $(expr ${off_boot_dec} + ${boot_size}) -gt "${off_kernel_dec}" ]; then
        bbfatal "norflash: imx-boot (${boot_size} bytes) overflows into kernel partition at ${off_kernel}"
    fi
    if [ $(expr ${off_kernel_dec} + ${kernel_size}) -gt "${off_dtb0_dec}" ]; then
        bbfatal "norflash: kernel (${kernel_size} bytes) overflows into DTB partition at ${off_dtb_0}"
    fi
    if [ $(expr ${off_rootfs_dec} + ${rootfs_size}) -gt "${flash_size_dec}" ]; then
        bbfatal "norflash: rootfs (${rootfs_size} bytes) overflows NOR flash end (size=${flash_size})"
    fi

    # Create a 0xFF-filled image matching the NOR erased state.
    # 0xFF-filled blank regions are required so JFFS2 cleanmarker scanning works.
    python3 -c "
import sys
size = ${flash_size_dec}
sys.stdout.buffer.write(b'\\xff' * size)
" > "${outfile}"

    # Overlay imx-boot at boot offset
    dd if="${boot_bin}" of="${outfile}" bs=1 seek="${off_boot_dec}" conv=notrunc

    # Overlay kernel Image at kernel offset
    dd if="${kernel_img}" of="${outfile}" bs=1 seek="${off_kernel_dec}" conv=notrunc

    # Overlay DTB slots at dtb offsets
    dd if="${dtb_0}" of="${outfile}" bs=1 seek="${off_dtb0_dec}" conv=notrunc
    dd if="${dtb_1}" of="${outfile}" bs=1 seek="${off_dtb1_dec}" conv=notrunc
    dd if="${dtb_2}" of="${outfile}" bs=1 seek="${off_dtb2_dec}" conv=notrunc
    dd if="${dtb_3}" of="${outfile}" bs=1 seek="${off_dtb3_dec}" conv=notrunc

    # Overlay JFFS2 rootfs at rootfs offset
    dd if="${rootfs_jffs2}" of="${outfile}" bs=1 seek="${off_rootfs_dec}" conv=notrunc

    bbnote "norflash: image created: $(stat -c%s ${outfile}) bytes"

    # Convenience symlink without the timestamp
    local link="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.norflash"
    ln -sf "${IMAGE_NAME}.norflash" "${link}"
}

# Register the type with the image infrastructure
IMAGE_TYPES += "norflash"
