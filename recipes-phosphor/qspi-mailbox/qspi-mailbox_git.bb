SUMMARY = "i.MX9 QSPI mailbox kernel driver (FPGA mailbox transport)"
DESCRIPTION = "Out-of-tree kernel module that talks to the MachXO5 FPGA over \
FlexSPI/QSPI and exposes the FPGA-backed subsystems (hwmon, virtual I2C/I3C, \
GPIO, PWM, IIO, eSPI, PLDM). Built with the userspace-simulator relay \
transport enabled (with the in-kernel mock as fallback)."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module

# Top of tree of the main branch.
SRC_URI = "git://git@bitbucket.sw.nxp.com/isp/bmc_mailbox.git;protocol=ssh;branch=main"
SRCREV = "${AUTOREV}"
PV = "1.0+git${SRCPV}"

# The module lives in a kbuild subdirectory of the repo. Point S at it so the
# module.bbclass build/install steps (which use M=${S}) drive the standard
# kbuild "modules"/"modules_install" targets directly.
#
# The git fetcher clones the repo to ${UNPACKDIR}/${BP} (for example
# sources/qspi-mailbox-1.0+git), not the legacy ${UNPACKDIR}/git stub, so
# S must descend from ${BP} to reach the module Makefile.
S = "${UNPACKDIR}/${BP}/kernel_driver/imx9-qspi-mailbox"


# Select the userspace FPGA simulator relay transport (implies the in-kernel
# mock as fallback). Matches the driver Makefile default, set explicitly here.
EXTRA_OEMAKE += "CONFIG_IMX9_QSPI_MB_USPACE=y"

RPROVIDES:${PN} += "kernel-module-imx9-qspi-mailbox"
