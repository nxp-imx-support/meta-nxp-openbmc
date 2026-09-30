# U-Boot environment for iMX93 BMC booting from SPI NOR flash (FlexSPI)
#
# NOR flash partition layout (must match machine conf, kernel DTS, and
# the norflash consolidated image offsets):
#   0x00000000 - 0x002BFFFF  (2.75 MB)  boot    flash.bin (imx-boot container)
#   0x002C0000 - 0x012BFFFF  (16 MB)    kernel  Linux kernel Image.gz
#   0x012C0000 - 0x0133FFFF  (512 KB)   dtb     Kernel device tree blob
#   0x01340000 - 0x03AFFFFF  (39.75 MB) rootfs  JFFS2 root filesystem
#   Total used: ~59 MB (0x03B00000)

# NOR flash boot is supported on the iMX93 EVK board only (not FRDM)
fdtfile=imx93-11x11-evk-bmc-host.dtb
kerneladdr=0xA1000000
fdtaddr=0xA0000000
unzipaddr=0xB0000000
kerneloffset=0x002C0000
kernelsize=0x01000000
fdtoffset=0x012C0000
fdtsize=0x80000

# Probe FlexSPI NOR, load compressed kernel + DTB, decompress, then boot
bootcmd=sf probe; sf read ${kerneladdr} ${kerneloffset} ${kernelsize}; sf read ${fdtaddr} ${fdtoffset} ${fdtsize}; unzip ${kerneladdr} ${unzipaddr}; booti ${unzipaddr} - ${fdtaddr}

# Console
console=ttyLP0,115200

# Kernel command line:
#   - root=/dev/mtdblock4  : rootfs is the 5th MTD block (index 4)
#     REQUIRES CONFIG_MTD_PARTITIONED_MASTER=y (set in nor-flexspi.cfg)
#     which exposes the full NOR as mtdblock0, shifting partition indices
#     by one.  If this config is disabled, rootfs becomes mtdblock3.
#   - rootfstype=jffs2     : JFFS2 filesystem on NOR
#   - Partition map is provided by the kernel DTS fixed-partitions node
bootargs=console=${console} root=/dev/mtdblock4 rw rootfstype=jffs2
