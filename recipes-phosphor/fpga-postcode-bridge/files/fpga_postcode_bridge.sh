#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Copyright 2026 NXP
#
# fpga_postcode_bridge - feed FPGA-simulated host POST codes into
# phosphor-post-code-manager so they appear in the Redfish PostCodes log
# service and the OpenBMC WebUI "POST code logs" page.
#
# Data path this script closes:
#
#   fpga_sim (9-stage host boot-progress model)
#     -> mailbox SENSOR DATA
#     -> kernel pldm.c sub-driver
#     -> debugfs  /sys/kernel/debug/imx9-qspi-pldm/<channel>/{post_code,boot_progress}
#     -> [ this bridge ]
#     -> /xyz/openbmc_project/state/boot/raw<N>  Value property
#     -> phosphor-post-code-manager
#     -> Redfish /redfish/v1/Systems/system/LogServices/PostCodes/Entries + WebUI
#
# On a real server the Value property is set by a snoop daemon reading the LPC
# Port-80 POST register (phosphor-host-postd / snoopd). There is no LPC bus in
# this FPGA-mailbox topology: the host POST byte arrives over the QSPI mailbox
# and is exposed by the PLDM sub-driver in debugfs instead. This bridge is the
# equivalent of snoopd for that transport - it is the only producer of POST
# codes on this board, so without it phosphor-post-code-manager runs but never
# records anything and the WebUI page stays empty.
#
# The property is a{sv}-typed "Value" on
# xyz.openbmc_project.State.Boot.Raw: a struct of (primary code, secondary
# code bytes). We publish the POST byte as the primary code and leave the
# secondary array empty, which is what a Port-80-only source reports.
#
# Only transitions are published. phosphor-post-code-manager appends a history
# record on every property change, so re-writing an unchanged value would
# inflate the log with duplicates of the current boot stage.
#
# Deliberately POSIX shell + busctl so it needs no cross-compilation against
# the sdbusplus sysroot, matching fpga_sel_bridge.sh in this layer.

set -u

# --- Configuration (override via environment / systemd drop-in) -------------

# debugfs channel directory created by the pldm.c sub-driver. The default
# matches the mailbox DTS channel-name "pldm_host0".
PLDM_DIR="${FPGA_POSTCODE_PLDM_DIR:-/sys/kernel/debug/imx9-qspi-pldm/pldm_host0}"

# Poll interval in seconds. The simulator advances one boot stage every 3s, so
# 2s is fast enough not to miss a stage.
POLL_SECS="${FPGA_POSTCODE_POLL_SECS:-2}"

# Host instance. phosphor-post-code-manager is templated per host and watches
# /xyz/openbmc_project/state/boot/raw<N>.
HOST_INSTANCE="${FPGA_POSTCODE_HOST_INSTANCE:-0}"

RAW_SVC="xyz.openbmc_project.State.Boot.Raw"
RAW_OBJ="/xyz/openbmc_project/state/boot/raw${HOST_INSTANCE}"
RAW_IFACE="xyz.openbmc_project.State.Boot.Raw"

log_info() { echo "fpga_postcode_bridge: $*" ; }

# --- Read one debugfs register file, echo its trimmed contents (or "") ------
read_reg() {
	reg_path="$PLDM_DIR/$1"
	if [ -r "$reg_path" ]; then
		tr -d ' \t\n' < "$reg_path"
	else
		echo ""
	fi
}

# --- Normalize a possibly-hex string to a decimal integer (0 on failure) ----
to_dec() {
	val="$1"
	[ -z "$val" ] && { echo 0; return; }
	printf '%d' "$val" 2>/dev/null || echo 0
}

# --- Publish one POST code -------------------------------------------------
#
# Value has signature (yay): a byte primary code plus a byte array of
# secondary codes. busctl argument form for that struct is:
#   "(yay)" <primary> <array-length> [bytes...]
# We report no secondary bytes, hence a length of 0.
publish_postcode() {
	code="$1"

	if busctl set-property "$RAW_SVC" "$RAW_OBJ" "$RAW_IFACE" Value \
		"(yay)" "$code" 0 >/dev/null 2>&1; then
		log_info "published POST code $code"
	else
		log_info "WARN: failed to publish POST code $code"
	fi
}

# --- Wait for the debugfs channel to appear --------------------------------
log_info "starting; watching $PLDM_DIR (poll ${POLL_SECS}s, host ${HOST_INSTANCE})"
while [ ! -d "$PLDM_DIR" ]; do
	log_info "waiting for $PLDM_DIR to appear..."
	sleep "$POLL_SECS"
done

# --- Wait for phosphor-post-code-manager to own the Raw bus name -----------
# systemd ordering only guarantees the unit started, not that the name is
# claimed; set-property against an unowned name fails.
tries=0
while [ "$tries" -lt 60 ]; do
	busctl status "$RAW_SVC" >/dev/null 2>&1 && break
	tries=$((tries + 1))
	sleep 1
done
if [ "$tries" -ge 60 ]; then
	log_info "timed out waiting for $RAW_SVC - exiting so systemd restarts us"
	exit 1
fi

# --- Main poll loop ---------------------------------------------------------
# last_code starts unset rather than 0 so the very first observed value is
# always published, including a genuine 0x00 first boot stage.
last_code=""

while true; do
	code=$(to_dec "$(read_reg post_code)")

	if [ "$code" != "$last_code" ]; then
		progress=$(read_reg boot_progress)
		log_info "POST transition: ${last_code:-none} -> $code (boot_progress=$progress)"
		publish_postcode "$code"
		last_code="$code"
	fi

	sleep "$POLL_SECS"
done
