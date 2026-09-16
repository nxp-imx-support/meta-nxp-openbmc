SUMMARY = "FPGA SIM host SEL / event-log bridge into phosphor-logging"
DESCRIPTION = "Polls the imx9-qspi-mailbox PLDM sub-driver SEL snapshot in \
debugfs and raises phosphor-logging entries so FPGA-simulated host events \
appear in the Redfish event log and the OpenBMC WebUI."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "fpga-sel-bridge.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = " \
    file://fpga_sel_bridge.sh \
    file://fpga-sel-bridge.service \
"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/fpga_sel_bridge.sh ${D}${bindir}/fpga_sel_bridge.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/fpga-sel-bridge.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${bindir}/fpga_sel_bridge.sh ${systemd_system_unitdir}/*"

# Runtime tools used by the bridge script.
RDEPENDS:${PN} += "phosphor-logging"
RDEPENDS:${PN} += "coreutils"
