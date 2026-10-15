SUMMARY = "i.MX9 QSPI mailbox kernel driver (FPGA mailbox transport)"
DESCRIPTION = "Out-of-tree kernel module that talks to the MachXO5 FPGA over \
FlexSPI/QSPI and exposes the FPGA-backed subsystems (hwmon, virtual I2C/I3C, \
GPIO, PWM, IIO, eSPI, PLDM). All transports are compiled in; the default \
(hw=1) drives the real FPGA, and hw=0 selects the userspace mock relay."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module

# bmc_mailbox source is centralized in conf/machine/include/nxp.inc
# (BMC_MAILBOX_SRC/_BRANCH/_SRCREV): Bitbucket for internal builds, public
# GitHub for external.
SRC_URI = "${BMC_MAILBOX_SRC};branch=${BMC_MAILBOX_BRANCH}"
SRCREV = "${BMC_MAILBOX_SRCREV}"
PV = "1.0+git${SRCPV}"

# The module lives in a kbuild subdirectory of the repo. Point S at it so the
# module.bbclass build/install steps (which use M=${S}) drive the standard
# kbuild "modules"/"modules_install" targets directly.
#
# The git fetcher clones the repo to ${UNPACKDIR}/${BP} (for example
# sources/qspi-mailbox-1.0+git), not the legacy ${UNPACKDIR}/git stub, so
# S must descend from ${BP} to reach the module Makefile.
S = "${UNPACKDIR}/${BP}/kernel_driver/imx9-qspi-mailbox"


# Driver configuration.
#
#   modprobe imx9-qspi-mailbox          -> hw=1 (default): real MachXO5-T FPGA
#                                          over SPI.
#   modprobe imx9-qspi-mailbox hw=0     -> userspace mock relay with in-kernel
#                                          mock fallback; needs no FPGA and no
#                                          DC-SCM hardware.
#
# KCS/IPMI bridge: register the FPGA eSPI KCS register triplet with the kernel
# KCS BMC framework so /dev/ipmi-kcs<N> appears for phosphor-ipmi-kcs / ipmid.
#
# OFF by default, and it has to be, because it cannot currently be satisfied on
# any i.MX machine. Enabling it unconditionally broke do_compile for every
# machine with:
CONFIG_IMX9_QSPI_MB_KCS ?= "n"
EXTRA_OEMAKE += "CONFIG_IMX9_QSPI_MB_KCS=${CONFIG_IMX9_QSPI_MB_KCS}"

RPROVIDES:${PN}:append = "${@'' if d.getVar('MACHINE') in ['latu-dcsm-imx95', 'frdm-imx95'] else ' kernel-module-imx9-qspi-mailbox'}"
