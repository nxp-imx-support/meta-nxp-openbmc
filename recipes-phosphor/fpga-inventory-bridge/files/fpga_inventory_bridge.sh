#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Copyright 2026 NXP
#
# fpga_inventory_bridge - publish simulated host FRU inventory on D-Bus so the
# Redfish Processors / Memory / PowerSupplies collections and the WebUI
# "Hardware status -> Inventory and LEDs" page are populated on a board that
# has no real host FRU EEPROMs.
#
# Why this exists
# ---------------
# Entity Manager turns each "Exposes" entry of imx91-system.json into an
# xyz.openbmc_project.Configuration.<Type> interface (Configuration.DimmSlot,
# Configuration.Processor, ...). bmcweb does NOT read those. It enumerates the
# Redfish hardware collections by asking the ObjectMapper for the inventory
# item interfaces instead:
#
#   /redfish/v1/Systems/system/Processors <- xyz.openbmc_project.Inventory.Item.Cpu
#   /redfish/v1/Systems/system/Memory     <- xyz.openbmc_project.Inventory.Item.Dimm
#   .../PowerSubsystem/PowerSupplies      <- xyz.openbmc_project.Inventory.Item.PowerSupply
#
# On a production system those interfaces are published by a FRU-reading
# daemon (phosphor-inventory-manager fed by real EEPROM/PLDM/IPMI FRU data).
# This board has no host FRUs, so nothing ever claims them and every
# collection reports Members@odata.count = 0 even though the FRU descriptions
# exist in the Entity Manager JSON.
#
# This bridge closes that gap for the simulator setup: it takes the FRU list
# below and publishes each item through phosphor-inventory-manager's Notify
# method, which creates the object with the proper Inventory.Item.* interface
# plus the Asset decorator that Redfish reads for Model / SerialNumber /
# Manufacturer / PartNumber.
#
# Data path:
#   this bridge
#     -> xyz.openbmc_project.Inventory.Manager  Notify
#     -> /xyz/openbmc_project/inventory/system/...  (Inventory.Item.* + Asset)
#     -> bmcweb ObjectMapper query
#     -> Redfish Processors / Memory / PowerSupplies + WebUI Inventory page
#
# Deliberately POSIX shell + busctl so it needs no cross-compilation against
# the sdbusplus sysroot, matching fpga_sel_bridge.sh in this layer.
#
# Idempotent: Notify on an existing path just refreshes the properties, so a
# restart is harmless and no state is kept on disk.

set -u

INV_SVC="xyz.openbmc_project.Inventory.Manager"
INV_OBJ="/xyz/openbmc_project/inventory"
INV_IFACE="xyz.openbmc_project.Inventory.Manager"

# Inventory root that phosphor-inventory-manager hangs objects under. Paths
# passed to Notify are relative to INV_OBJ.
SYS="/system/chassis"

log_info() { echo "fpga_inventory_bridge: $*" ; }

# ---------------------------------------------------------------------------
# publish_item - create/refresh one inventory object
#
#   $1 relative object path (below /xyz/openbmc_project/inventory)
#   $2 item interface to claim (e.g. xyz.openbmc_project.Inventory.Item.Cpu)
#   $3 pretty name        -> Inventory.Item PrettyName
#   $4 manufacturer       -> Decorator.Asset Manufacturer
#   $5 model              -> Decorator.Asset Model
#   $6 part number        -> Decorator.Asset PartNumber
#   $7 serial number      -> Decorator.Asset SerialNumber
#
# Notify takes a{oa{sa{sv}}}: a map of object path -> interface -> property ->
# variant. Three interfaces are published per item:
#   - the Inventory.Item.<Type> marker interface bmcweb enumerates on
#   - Inventory.Item      (PrettyName + Present, so the item shows as present)
#   - Decorator.Asset     (the fields Redfish renders)
# ---------------------------------------------------------------------------
publish_item() {
	_path="$1"; _iface="$2"; _name="$3"
	_mfr="$4"; _model="$5"; _pn="$6"; _sn="$7"

	busctl call "$INV_SVC" "$INV_OBJ" "$INV_IFACE" Notify \
		"a{oa{sa{sv}}}" 1 \
		"$_path" 3 \
		"$_iface" 0 \
		"xyz.openbmc_project.Inventory.Item" 2 \
			"PrettyName" s "$_name" \
			"Present"    b true \
		"xyz.openbmc_project.Inventory.Decorator.Asset" 4 \
			"Manufacturer" s "$_mfr" \
			"Model"        s "$_model" \
			"PartNumber"   s "$_pn" \
			"SerialNumber" s "$_sn" \
		>/dev/null 2>&1 \
	&& log_info "published $_path ($_iface)" \
	|| log_info "FAILED to publish $_path ($_iface)"
}

# ---------------------------------------------------------------------------
# Simulated host FRU set.
#
# Keep this list consistent with the "Exposes" array of imx91-system.json:
# that file documents the topology for Entity Manager, this list is what
# actually reaches Redfish. Values are representative of the iMX91 FRDM BMC
# reference setup and are simulation data, not read from hardware.
# ---------------------------------------------------------------------------
publish_all() {
	# -- Processors ----------------------------------------------------
	publish_item "$SYS/motherboard/cpu0" \
		"xyz.openbmc_project.Inventory.Item.Cpu" \
		"iMX91 Application Processor" \
		"NXP" "i.MX 91 Cortex-A55" "MIMX9131" "CPU-0001"

	# -- Memory (DIMM slots) -------------------------------------------
	publish_item "$SYS/motherboard/dimm0" \
		"xyz.openbmc_project.Inventory.Item.Dimm" \
		"DIMM 0" \
		"Micron" "MT41K256M16" "MT41K256M16TW" "DIMM-0001"

	publish_item "$SYS/motherboard/dimm1" \
		"xyz.openbmc_project.Inventory.Item.Dimm" \
		"DIMM 1" \
		"Micron" "MT41K256M16" "MT41K256M16TW" "DIMM-0002"

	# -- Power supplies ------------------------------------------------
	publish_item "$SYS/powersupply0" \
		"xyz.openbmc_project.Inventory.Item.PowerSupply" \
		"Power Supply 0" \
		"NXP" "PSU-12V-65W" "PSU-65W-A0" "PSU-0001"

	publish_item "$SYS/powersupply1" \
		"xyz.openbmc_project.Inventory.Item.PowerSupply" \
		"Power Supply 1" \
		"NXP" "PSU-12V-65W" "PSU-65W-A0" "PSU-0002"

	# -- Fans ----------------------------------------------------------
	# The fan tach readings themselves come from the FPGA mailbox via
	# dbus-sensors; these objects give the WebUI inventory page a FRU to
	# attach each reading to.
	for i in 0 1 2 3 4 5; do
		publish_item "$SYS/fan$i" \
			"xyz.openbmc_project.Inventory.Item.Fan" \
			"Fan $i" \
			"NXP" "FAN-40MM" "FAN-40-A0" "FAN-000$i"
	done

	# -- FPGA assembly -------------------------------------------------
	publish_item "$SYS/motherboard/fpga0" \
		"xyz.openbmc_project.Inventory.Item.Board" \
		"FPGA Mailbox Assembly" \
		"Lattice" "MachXO5-T" "LFMXO5-25-7BG256I" "FPGA-0001"
}

# ---------------------------------------------------------------------------
# Wait for phosphor-inventory-manager to own its bus name before publishing.
# systemd ordering only guarantees the unit started, not that the name is
# claimed, and Notify on an unowned name fails silently.
# ---------------------------------------------------------------------------
wait_for_inventory_manager() {
	_tries=0
	while [ "$_tries" -lt 60 ]; do
		if busctl status "$INV_SVC" >/dev/null 2>&1; then
			return 0
		fi
		_tries=$((_tries + 1))
		sleep 1
	done
	log_info "timed out waiting for $INV_SVC"
	return 1
}

main() {
	wait_for_inventory_manager || exit 1
	log_info "publishing simulated host FRU inventory"
	publish_all
	log_info "done"
}

main "$@"
