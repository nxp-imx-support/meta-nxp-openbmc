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

# ---------------------------------------------------------------------------
# Host FRU identity, read from the FPGA over the mailbox.
#
# The managed server's identity belongs to the host, so it must be read from
# the FPGA rather than hard-coded here. The PLDM sub-driver exposes each field
# as a debugfs file that it assembles from the host FRU register window:
#
#   fru_manufacturer  fru_model  fru_serial  fru_part_number
#
# On a real platform these originate in the host's FRU EEPROM / PLDM FRU
# record; with fpga_sim they come from the simulator's FRU model. Either way
# the BMC just reads them.
#
# If the files are missing (older DTS without the nxp,fru-*-address
# properties, or the mailbox driver not loaded) the corresponding Redfish
# field is left empty rather than being filled with an invented value - an
# empty field is honest about the data being unavailable, a fabricated one is
# not.
# ---------------------------------------------------------------------------
PLDM_DIR="${FPGA_INV_PLDM_DIR:-/sys/kernel/debug/imx9-qspi-pldm/pldm_host0}"

HOST_MANUFACTURER=""
HOST_MODEL=""
HOST_SERIAL=""
HOST_PART=""

# Inventory root that phosphor-inventory-manager hangs objects under. Paths
# passed to Notify are relative to INV_OBJ.
SYS="/system/chassis"

log_info() { echo "fpga_inventory_bridge: $*" ; }

# Read one host FRU string from the PLDM debugfs surface, or "" if absent.
read_fru() {
	_f="$PLDM_DIR/$1"
	if [ -r "$_f" ]; then
		tr -d '\n' < "$_f" 2>/dev/null
	else
		echo ""
	fi
}

# ---------------------------------------------------------------------------
# Populate HOST_* from the FPGA. Waits briefly for the debugfs surface: the
# mailbox driver has to finish its handshake before the PLDM bank appears, and
# on a cold boot this service can win that race.
# ---------------------------------------------------------------------------
load_host_fru() {
	_tries=0
	while [ "$_tries" -lt 30 ]; do
		[ -r "$PLDM_DIR/fru_model" ] && break
		_tries=$((_tries + 1))
		sleep 1
	done

	HOST_MANUFACTURER=$(read_fru fru_manufacturer)
	HOST_MODEL=$(read_fru fru_model)
	HOST_SERIAL=$(read_fru fru_serial)
	HOST_PART=$(read_fru fru_part_number)

	if [ -n "$HOST_MODEL" ] || [ -n "$HOST_SERIAL" ]; then
		log_info "host FRU from FPGA: mfr='$HOST_MANUFACTURER' model='$HOST_MODEL' sn='$HOST_SERIAL' pn='$HOST_PART'"
	else
		log_info "WARN: no host FRU available under $PLDM_DIR - server identity fields will be empty"
	fi
}

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
# Host FRU set.
#
# The chassis-level identity (manufacturer / model / serial / part) is the
# HOST_* data read from the FPGA above - it describes the managed server and is
# what Redfish shows as "Server information". It is deliberately not
# hard-coded here.
#
# The per-component descriptors (which DIMM part, which PSU model) are not
# carried by the host FRU register window, which models a chassis-level record
# only. Rather than invent per-part strings, each component inherits the host
# manufacturer and is distinguished by its PrettyName plus a positional serial
# suffix derived from the host serial. That keeps every string traceable to
# data the FPGA actually reported. Extending the FPGA FRU window with
# per-component records is the natural follow-up once the real host provides
# them.
#
# Keep the component list consistent with the "Exposes" array of
# imx91-system.json: that file documents the topology for Entity Manager,
# this list is what actually reaches Redfish.
# ---------------------------------------------------------------------------
publish_all() {
	# Positional serials derived from the host serial so each component is
	# distinguishable while remaining traceable to the reported host FRU.
	_sn="${HOST_SERIAL:-UNKNOWN}"

	# -- Chassis: the managed server itself ----------------------------
	publish_item "$SYS" \
		"xyz.openbmc_project.Inventory.Item.Chassis" \
		"${HOST_MODEL:-Managed Server}" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$HOST_SERIAL"

	# -- Processors ----------------------------------------------------
	publish_item "$SYS/motherboard/cpu0" \
		"xyz.openbmc_project.Inventory.Item.Cpu" \
		"Processor 0" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$_sn-CPU0"

	# -- Memory (DIMM slots) -------------------------------------------
	publish_item "$SYS/motherboard/dimm0" \
		"xyz.openbmc_project.Inventory.Item.Dimm" \
		"DIMM 0" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$_sn-DIMM0"

	publish_item "$SYS/motherboard/dimm1" \
		"xyz.openbmc_project.Inventory.Item.Dimm" \
		"DIMM 1" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$_sn-DIMM1"

	# -- Power supplies ------------------------------------------------
	publish_item "$SYS/powersupply0" \
		"xyz.openbmc_project.Inventory.Item.PowerSupply" \
		"Power Supply 0" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$_sn-PSU0"

	publish_item "$SYS/powersupply1" \
		"xyz.openbmc_project.Inventory.Item.PowerSupply" \
		"Power Supply 1" \
		"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" "$_sn-PSU1"

	# -- Fans ----------------------------------------------------------
	# The fan tach readings themselves come from the FPGA mailbox via
	# dbus-sensors; these objects give the WebUI inventory page a FRU to
	# attach each reading to.
	for i in 0 1 2 3 4 5; do
		publish_item "$SYS/fan$i" \
			"xyz.openbmc_project.Inventory.Item.Fan" \
			"Fan $i" \
			"$HOST_MANUFACTURER" "$HOST_MODEL" "$HOST_PART" \
			"$_sn-FAN$i"
	done

	# -- FPGA assembly -------------------------------------------------
	# The management controller itself, not part of the host FRU record,
	# so its identity is genuinely local to this board.
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
	load_host_fru
	log_info "publishing host FRU inventory"
	publish_all
	log_info "done"
}

main "$@"
