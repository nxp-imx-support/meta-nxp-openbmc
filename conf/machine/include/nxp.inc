# Copyright 2025-2026 NXP

require conf/machine/include/arm/armv8-2a/tune-cortexa55.inc

PREFERRED_PROVIDER_virtual/kernel = "linux-nxp"
IMX_DEFAULT_KERNEL = "linux-nxp"

MACHINEOVERRIDES .= ":nxp"

BMC_LINUX_SRC_INTERNAL = "git://git@bitbucket.sw.nxp.com/isp/linux-imx.git;protocol=ssh"
#BMC_LINUX_SRC_GITHUB = "git://github.com/nxp-imx/linux-imx.git;protocol=https"
BMC_LINUX_SRC_GITHUB = "git://github.com/nxp-qoriq/linux.git;protocol=https"

# Select the kernel source.
#
# Defaults to "0": an external build from the public GitHub tree
# (BMC_LINUX_SRC_GITHUB), so that a clean clone builds for anyone without
# needing SSH access to bitbucket.sw.nxp.com. Set it to "1" to build from the
# internal NXP Bitbucket mirror (BMC_LINUX_SRC_INTERNAL) - note that this is a
# change of default: builds that previously relied on the implicit internal
# mirror must now set BMC_LINUX_USE_INTERNAL = "1" explicitly in local.conf.
#
# This same switch also selects the bmc_mailbox source below, and gates the
# internal-only OBMF packages in the image bbappends.
#
# Both the internal and public branches already carry all of the OpenBMC
# downstream kernel changes, so the linux-nxp recipe applies no *.patch files
# in either case - only the OpenBMC *.cfg defconfig fragments are added.
BMC_LINUX_USE_INTERNAL ?= "0"

BMC_LINUX_BRANCH_INTERNAL = "lf-6.18.y-bmc"
BMC_LINUX_BRANCH_GITHUB = "lf-6.18.y-bmc"
BMC_LINUX_SRCREV_GITHUB = "fecd782cfe5a505ceb2b7ee8d27b8df40edb567e"

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

# --- bmc_mailbox source (consumed by the mock-server and qspi-mailbox recipes) ---
#
# Centralized here so both recipes resolve the same repo/branch/rev from one
# place. Internal builds (BMC_LINUX_USE_INTERNAL=1) use the Bitbucket mirror;
# external builds use the public GitHub tree. The branch name is shared.
BMC_MAILBOX_SRC_INTERNAL = "git://git@bitbucket.sw.nxp.com/isp/bmc_mailbox.git;protocol=ssh"
BMC_MAILBOX_SRC_GITHUB = "git://github.com/nxp-imx-support/bmc_mailbox;protocol=https"
BMC_MAILBOX_BRANCH = "wrynose"
BMC_MAILBOX_SRCREV_GITHUB = "06f3e8575faafb938cba8625097814c67356b247"

BMC_MAILBOX_SRC = "${BMC_MAILBOX_SRC_GITHUB}"
BMC_MAILBOX_SRCREV = "${BMC_MAILBOX_SRCREV_GITHUB}"

# Internal NXP source: tracks the tip of the branch during development.
# AUTOREV is assigned directly so the fetcher can resolve it early.
BMC_MAILBOX_SRC:internal = "${BMC_MAILBOX_SRC_INTERNAL}"
BMC_MAILBOX_SRCREV:internal = "${AUTOREV}"

# --- OBMF (ioe_obmf_linux) source (consumed by obmf-driver and obmf-bmc-apps) ---
#
# OBMF is an internal-only component: both recipes are only installed when
# BMC_LINUX_USE_INTERNAL=1, so there is a single Bitbucket URL and no public
# mirror.
OBMF_SRC = "git://git@bitbucket.sw.nxp.com/sbs/ioe_obmf_linux.git;protocol=ssh"
OBMF_BRANCH = "main"
OBMF_SRCREV = "45491e45c23963dfee734c3609c0aa10678cec5c"

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
