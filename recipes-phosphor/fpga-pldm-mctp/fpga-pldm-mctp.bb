SUMMARY = "FPGA SIM PLDM-over-MCTP responder"
DESCRIPTION = "Presents the FPGA SIM as a PLDM terminus on the BMC MCTP stack. \
Implements the PLDM base and platform commands (GetPLDMTypes, GetPDR, \
GetSensorReading, ...) needed for pldmd platform-mc terminus discovery, and \
serves one numeric temperature sensor whose value is read live from the \
mailbox-backed hwmon device."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit systemd

SYSTEMD_SERVICE:${PN} = "fpga-pldm-mctp.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = " \
    file://fpga_pldm_mctp.c \
    file://fpga-pldm-mctp.service \
"

S = "${UNPACKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -Wall -Wextra -o fpga_pldm_mctp \
        ${UNPACKDIR}/fpga_pldm_mctp.c
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 fpga_pldm_mctp ${D}${bindir}/fpga_pldm_mctp

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/fpga-pldm-mctp.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${bindir}/fpga_pldm_mctp ${systemd_system_unitdir}/*"

# The MCTP transport (AF_MCTP) is provided by the kernel; pldm/pldmtool drive
# discovery. Recommend them so the demo has something to talk to it.
RRECOMMENDS:${PN} += "pldm pldmtool"
