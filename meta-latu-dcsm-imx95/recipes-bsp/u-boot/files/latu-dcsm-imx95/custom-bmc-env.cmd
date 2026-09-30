# U-Boot environment for iMX95 LATU-DCSM BMC booting from SD/MMC
#
# This is the compiled-in default environment for the SD boot variant.
# U-Boot saves/loads runtime env from MMC at CONFIG_ENV_OFFSET (0x49A0000).

# Default DTB for LATU-DCSM board
fdtfile=imx95-19x19-latu-dcsm.dtb

# Console
console=ttyLP0,115200

# Kernel boot arguments
bootargs=console=ttyLP0,115200 earlycon root=/dev/mmcblk1p2 rw rootwait

# Boot delay (seconds)
bootdelay=3
