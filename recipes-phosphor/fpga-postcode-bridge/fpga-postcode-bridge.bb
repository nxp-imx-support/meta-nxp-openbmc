SUMMARY = "FPGA SIM host POST code bridge into phosphor-post-code-manager"
DESCRIPTION = "Polls the imx9-qspi-mailbox PLDM sub-driver POST code and boot \
progress registers in debugfs and republishes each transition on \
xyz.openbmc_project.State.Boot.Raw, so FPGA-simulated host POST codes are \
recorded by phosphor-post-code-manager and appear in the Redfish PostCodes \
log service and the OpenBMC WebUI. Fills the role snoopd plays on an LPC \
based system, which this FPGA-mailbox topology has no equivalent of."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "fpga-postcode-bridge.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = " \
    file://fpga_postcode_bridge.sh \
    file://fpga-postcode-bridge.service \
"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/fpga_postcode_bridge.sh ${D}${bindir}/fpga_postcode_bridge.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/fpga-postcode-bridge.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${bindir}/fpga_postcode_bridge.sh ${systemd_system_unitdir}/*"

# phosphor-post-code-manager owns the State.Boot.Raw object this bridge writes
# to and is what turns those writes into the Redfish PostCodes log, so it must
# be on the image for the bridge to do anything.
RDEPENDS:${PN} += "phosphor-post-code-manager"
RDEPENDS:${PN} += "coreutils"
