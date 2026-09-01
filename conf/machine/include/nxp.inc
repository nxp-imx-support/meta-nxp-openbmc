# Copyright 2025-2026 NXP

require conf/machine/include/arm/armv8-2a/tune-cortexa55.inc

PREFERRED_PROVIDER_virtual/kernel = "linux-nxp"
IMX_DEFAULT_KERNEL = "linux-nxp"

MACHINEOVERRIDES .= ":nxp"

BMC_LINUX_SRC_INTERNAL = "git://git@bitbucket.sw.nxp.com/isp/linux-imx.git;protocol=ssh"
#BMC_LINUX_SRC_GITHUB = "git://github.com/nxp-imx/linux-imx.git;protocol=https"
BMC_LINUX_SRC_GITHUB = "git://github.com/nxp-qoriq/linux.git;protocol=https"

# Select the kernel source. Set to "1" to build from the internal NXP mirror
# (BMC_LINUX_SRC_INTERNAL); set to "0" to build from the public GitHub tree
# (BMC_LINUX_SRC_GITHUB). The internal branch already carries all of the required patches.
BMC_LINUX_USE_INTERNAL ?= "1"

BMC_LINUX_BRANCH_INTERNAL = "lf-6.18.y-bmc"
BMC_LINUX_BRANCH_GITHUB = "lf-6.18.y-bmc"
BMC_LINUX_SRCREV_GITHUB = "f49f45233f7b10006ce7e9c826ee882bb14ac8b5"

# public GitHub
BMC_LINUX_SRC = "${BMC_LINUX_SRC_GITHUB}"
BMC_LINUX_BRANCH = "${BMC_LINUX_BRANCH_GITHUB}"
BMC_LINUX_SRCREV = "${BMC_LINUX_SRCREV_GITHUB}"

# Internal NXP source
# AUTOREV is assigned directly so the fetcher can resolve it early.
BMC_LINUX_SRC:internal = "${BMC_LINUX_SRC_INTERNAL}"
BMC_LINUX_BRANCH:internal = "${BMC_LINUX_BRANCH_INTERNAL}"
BMC_LINUX_SRCREV:internal = "${AUTOREV}"

# Automatically enable the internal override when requested.
OVERRIDES:append = "${@':internal' if d.getVar('BMC_LINUX_USE_INTERNAL') == '1' else ''}"

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
