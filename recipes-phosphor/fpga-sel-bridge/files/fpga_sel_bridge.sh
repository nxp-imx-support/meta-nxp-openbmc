#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Copyright 2026 NXP
#
# fpga_sel_bridge - forward FPGA-simulated host SEL / event-log records into
# OpenBMC phosphor-logging so they appear in the Redfish LogService and the
# WebUI event log.
#
# Data path this script closes:
#
#   fpga_sim (host SEL model)
#     -> mailbox SENSOR DATA
#     -> kernel pldm.c sub-driver
#     -> debugfs  /sys/kernel/debug/imx9-qspi-pldm/<channel>/sel_*
#     -> [ this bridge ]
#     -> busctl call xyz.openbmc_project.Logging  Create
#     -> Redfish /redfish/v1/Systems/system/LogServices/EventLog + WebUI
#
# The PLDM sub-driver exposes a read-only SEL snapshot per channel:
#   sel_count     - number of SEL entries recorded so far (decimal)
#   sel_latest_id - record id of the most recent SEL entry (decimal)
#   sel_latest_ev - event data word of the most recent SEL entry (hex)
#   sel_latest_ts - timestamp (epoch seconds) of the latest entry (decimal)
#   boot_progress - current PLDM boot progress code (hex)
#   boot_error    - last boot error code, 0 = none (hex)
#
# The bridge polls sel_count; each time it increases it reads the latest
# record fields and raises one phosphor-logging entry. It also raises an
# entry when boot_error becomes non-zero. State is kept in memory only, so a
# restart re-syncs to the current count without replaying old records.
#
# This is intentionally a POSIX shell + busctl implementation so it needs no
# cross-compilation against the sdbusplus sysroot and can be dropped onto any
# OpenBMC image that ships phosphor-logging.

set -u

# --- Configuration (override via environment / systemd drop-in) -------------

# debugfs channel directory created by the pldm.c sub-driver. The default
# matches the mailbox-mock DTS channel-name "pldm_host0".
PLDM_DIR="${FPGA_SEL_PLDM_DIR:-/sys/kernel/debug/imx9-qspi-pldm/pldm_host0}"

# Poll interval in seconds.
POLL_SECS="${FPGA_SEL_POLL_SECS:-5}"

# phosphor-logging D-Bus destination.
LOG_SVC="xyz.openbmc_project.Logging"
LOG_OBJ="/xyz/openbmc_project/logging"
LOG_IFACE="xyz.openbmc_project.Logging.Create"

# Message-registry-style identifier used for the log Message field.
SEL_MESSAGE="${FPGA_SEL_MESSAGE:-xyz.openbmc_project.Host.Error.Event}"

log_info() { echo "fpga_sel_bridge: $*" ; }

# --- Read one debugfs register file, echo its trimmed contents (or "") ------
read_reg() {
	reg_path="$PLDM_DIR/$1"
	if [ -r "$reg_path" ]; then
		# debugfs values may be "0x1a" or decimal; strip whitespace.
		tr -d ' \t\n' < "$reg_path"
	else
		echo ""
	fi
}

# --- Normalize a possibly-hex string to a decimal integer (0 on failure) ----
to_dec() {
	val="$1"
	[ -z "$val" ] && { echo 0; return; }
	case "$val" in
	0x*|0X*)	printf '%d' "$val" 2>/dev/null || echo 0 ;;
	*)		printf '%d' "$val" 2>/dev/null || echo 0 ;;
	esac
}

# --- Raise one phosphor-logging entry --------------------------------------
#
# Create(Message: s, Severity: s, AdditionalData: a{ss})
# AdditionalData is passed as a busctl dict of string->string pairs. We encode
# the SEL record fields so they are visible in the Redfish log entry.
raise_log() {
	msg="$1"
	severity="$2"
	shift 2
	# Remaining args are KEY VALUE pairs for AdditionalData.
	n_pairs=0
	pairs=""
	while [ "$#" -ge 2 ]; do
		key="$1"; value="$2"; shift 2
		pairs="$pairs $key $value"
		n_pairs=$((n_pairs + 1))
	done

	# busctl signature: s s a{ss}
	# The a{ss} argument is: <count> then <count> * (key value).
	# shellcheck disable=SC2086
	if busctl call "$LOG_SVC" "$LOG_OBJ" "$LOG_IFACE" Create \
		"ssa{ss}" "$msg" "$severity" "$n_pairs" $pairs >/dev/null 2>&1; then
		log_info "raised log: $msg [$severity]"
	else
		log_info "WARN: busctl Create failed for: $msg"
	fi
}

# --- Wait for the debugfs channel to appear --------------------------------
log_info "starting; watching $PLDM_DIR (poll ${POLL_SECS}s)"
while [ ! -d "$PLDM_DIR" ]; do
	log_info "waiting for $PLDM_DIR to appear..."
	sleep "$POLL_SECS"
done

# --- Sync baseline so we do not replay pre-existing records -----------------
last_count=$(to_dec "$(read_reg sel_count)")
last_boot_error=$(to_dec "$(read_reg boot_error)")
log_info "baseline sel_count=$last_count boot_error=$last_boot_error"

# --- Main poll loop ---------------------------------------------------------
while true; do
	sleep "$POLL_SECS"

	count=$(to_dec "$(read_reg sel_count)")
	boot_error=$(to_dec "$(read_reg boot_error)")

	# New SEL record(s)?
	if [ "$count" -gt "$last_count" ]; then
		sel_id=$(read_reg sel_latest_id)
		sel_ev=$(read_reg sel_latest_ev)
		sel_ts=$(read_reg sel_latest_ts)
		boot_progress=$(read_reg boot_progress)

		raise_log "$SEL_MESSAGE" \
			"xyz.openbmc_project.Logging.Entry.Level.Warning" \
			"SEL_RECORD_ID"   "$sel_id" \
			"SEL_EVENT_DATA"  "$sel_ev" \
			"SEL_TIMESTAMP"   "$sel_ts" \
			"BOOT_PROGRESS"   "$boot_progress" \
			"SEL_COUNT"       "$count"

		last_count="$count"
	fi

	# New boot error?
	if [ "$boot_error" -ne 0 ] && [ "$boot_error" -ne "$last_boot_error" ]; then
		raise_log "$SEL_MESSAGE" \
			"xyz.openbmc_project.Logging.Entry.Level.Error" \
			"BOOT_ERROR"    "$boot_error" \
			"BOOT_PROGRESS" "$(read_reg boot_progress)"
	fi
	last_boot_error="$boot_error"
done
