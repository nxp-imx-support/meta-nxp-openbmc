SUMMARY = "Publish simulated host FRU inventory for Redfish and the WebUI"
DESCRIPTION = "Publishes the simulated host FRU set (processor, DIMM slots, \
power supplies, fans, FPGA assembly) through phosphor-inventory-manager so the \
Redfish Processors / Memory / PowerSupplies collections and the WebUI \
\"Inventory and LEDs\" page are populated on a board that has no real host FRU \
EEPROMs. Entity Manager only creates Configuration.* interfaces from its JSON, \
which bmcweb does not enumerate; this bridge claims the Inventory.Item.* \
interfaces bmcweb actually queries."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "fpga-inventory-bridge.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = " \
    file://fpga_inventory_bridge.sh \
    file://fpga-inventory-bridge.service \
"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/fpga_inventory_bridge.sh ${D}${bindir}/fpga_inventory_bridge.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/fpga-inventory-bridge.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${bindir}/fpga_inventory_bridge.sh ${systemd_system_unitdir}/*"

# phosphor-inventory-manager owns the Notify method this bridge calls and holds
# the objects it creates.
RDEPENDS:${PN} += "phosphor-inventory-manager"
RDEPENDS:${PN} += "coreutils"
