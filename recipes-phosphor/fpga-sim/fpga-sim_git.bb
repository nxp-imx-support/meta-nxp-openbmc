SUMMARY = "FPGA mailbox simulator daemon (fpga_sim)"
DESCRIPTION = "Userspace daemon that plays the MachXO5 FPGA over the \
imx9-qspi-mailbox relay character device (/dev/qspi-mb-sim*). It answers raw \
mailbox request packets so the FPGA-backed subsystems can be exercised without \
real hardware. Installed as a plain binary; run on demand (not a service)."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

# Top of tree of the main branch.
SRC_URI = "git://git@bitbucket.sw.nxp.com/isp/bmc_mailbox.git;protocol=ssh;branch=main"
SRCREV = "${AUTOREV}"
PV = "1.0+git${SRCPV}"

# The git fetcher clones the repo to ${UNPACKDIR}/${BP} (for example
# sources/fpga-sim-1.0+git), not the legacy ${UNPACKDIR}/git stub.
S = "${UNPACKDIR}/${BP}"


# fpga_sim.c includes the driver UAPI header shared via the relay ABI.
DRV_HEADER_DIR = "${S}/kernel_driver/imx9-qspi-mailbox"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -Wall -Wextra -O2 -pthread \
        -I${DRV_HEADER_DIR} \
        -o fpga_sim ${S}/app/fpga_sim.c -pthread
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 fpga_sim ${D}${bindir}/fpga_sim
}

FILES:${PN} += "${bindir}/fpga_sim"
