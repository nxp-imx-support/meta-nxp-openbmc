# Copyright 2025-2026 NXP

require conf/machine/include/arm/armv8-2a/tune-cortexa55.inc

PREFERRED_PROVIDER_virtual/kernel = "linux-nxp"
IMX_DEFAULT_KERNEL = "linux-nxp"

MACHINEOVERRIDES .= ":nxp"

BMC_LINUX_SRC_INTERNAL = "git://git@bitbucket.sw.nxp.com/lfac/linux-lts-nxp.git;protocol=ssh"
BMC_LINUX_SRC_GITHUB = "git://github.com/nxp-imx/linux-imx.git;protocol=https"

BMC_LINUX_SRC = "${BMC_LINUX_SRC_GITHUB}"
BMC_LINUX_BRANCH = "lf-6.18.y"
BMC_LINUX_SRCREV = "07bb2ca4e8a7b292490c183a02dc8bff6645aab7"
BMC_LINUX_DEFCONFIG ?= "imx_v8_defconfig"

KERNEL_BOOTCMD ??= "bootm"
KERNEL_IMAGETYPE_UBOOT ??= "uImage"
KERNEL_IMAGETYPE_DIRECT ??= "Image"
KERNEL_IMAGETYPE ?= "${@bb.utils.contains('RPI_USE_U_BOOT', '1', \
        '${KERNEL_IMAGETYPE_UBOOT}', '${KERNEL_IMAGETYPE_DIRECT}', d)}"

MACHINE_EXTRA_RRECOMMENDS += "kernel-modules udev-rules-imx"
MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += "${@oe.utils.conditional('ENABLE_I2C', '1', 'kernel-module-i2c-dev kernel-module-i2c-bcm2708', '', d)}"
MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += "${@oe.utils.conditional('ENABLE_IR', '1', 'kernel-module-gpio-ir kernel-module-gpio-ir-tx', '', d)}"
MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += "${@oe.utils.conditional('ENABLE_GPIO_SHUTDOWN', '1', 'gpio-shutdown kernel-module-gpio-keys', '', d)}"
