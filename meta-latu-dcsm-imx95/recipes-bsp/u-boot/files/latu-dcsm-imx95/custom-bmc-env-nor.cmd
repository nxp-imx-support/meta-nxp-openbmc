# U-Boot environment for iMX95 EVK BMC booting from SPI NOR flash (FlexSPI1)
#
# NOR flash partition layout (must match machine conf, kernel DTS, and
# the norflash consolidated image offsets):
#   0x00000000 - 0x002DFFFF  (2.875 MB)   boot    flash.bin (imx-boot container)
#   0x002E0000 - 0x00E3FFFF  (14.25 MB)   kernel  Linux kernel Image.gz
#   0x01120000 - 0x0007FFFF  (512 KB)     dtb     Kernel device tree blob
#   0x011A0000 - 0x037FFFFF  (56 MB)      rootfs  JFFS2 root filesystem
#   0x49A0000  - 0x49BFFFFF  (76 KB)      env     U-Boot environment (primary)
#   (redundant env at 0x49F0000 per CONFIG_ENV_OFFSET_REDUND in defconfig)

fdtfile=imx95-19x19-evk-bmc.dtb
kerneladdrcomp=0xA1000000
kerneladdr=0xB0000000
loadaddr=0x90400000
fdtaddr=0xA0000000
kerneloffset=0x2E0000
kernelsize=0xE40000
fdtoffset=0x1160000
fdtoffset1=0x1120000
fdtoffset2=0x1140000
fdtoffset3=0x1160000
fdtoffset4=0x1180000
fdtsize=0x20000

# Probe FlexSPI1 NOR and load kernel + DTB from fixed NOR offsets
bootcmd=sf probe; sf read 0xA0000000 0x1160000 0x20000; sf read 0xA1000000 0x2E0000 0xE40000; unzip 0xA1000000 0xB0000000; booti 0xB0000000 - 0xA0000000
bootcmd1=sf probe; sf read ${fdtaddr} ${fdtoffset1} ${fdtsize}; sf read ${kerneladdrcomp} ${kerneloffset} ${kernelsize}; unzip ${kerneladdrcomp} ${kerneladdr}; booti ${kerneladdr} - ${fdtaddr}
bootcmd2=sf probe; sf read ${fdtaddr} ${fdtoffset2} ${fdtsize}; sf read ${kerneladdrcomp} ${kerneloffset} ${kernelsize}; unzip ${kerneladdrcomp} ${kerneladdr}; booti ${kerneladdr} - ${fdtaddr}
bootcmd3=sf probe; sf read ${fdtaddr} ${fdtoffset3} ${fdtsize}; sf read ${kerneladdrcomp} ${kerneloffset} ${kernelsize}; unzip ${kerneladdrcomp} ${kerneladdr}; booti ${kerneladdr} - ${fdtaddr}
bootcmd4=sf probe; sf read ${fdtaddr} ${fdtoffset4} ${fdtsize}; sf read ${kerneladdrcomp} ${kerneloffset} ${kernelsize}; unzip ${kerneladdrcomp} ${kerneladdr}; booti ${kerneladdr} - ${fdtaddr}

# Console
console=ttyLP0,115200

# Kernel command line:
#   - earlycon               : enable early console output
#   - root=/dev/mtdblock3    : rootfs is the 4th MTD partition (index 3)
#   - rootfstype=jffs2       : JFFS2 filesystem on NOR
bootargs=console=ttyLP0,115200 earlycon root=/dev/mtdblock3 rw rootfstype=jffs2
