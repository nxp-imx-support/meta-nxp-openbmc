#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# host_reboot.sh - restart the host
#
# Usage: host_reboot.sh [graceful|force]
#   graceful (default) - ask the host firmware to restart itself over the ACPI
#                        reset-warning sideband, wait for it to come back, and
#                        escalate to a force reset only on timeout.
#   force              - reset the host immediately, no negotiation.
#
# This is a WARM reboot in both modes: the host is reset but chassis power is
# not dropped. The previous version called power_off followed by power_on, i.e.
# a full cold power cycle, which is not what either warm-reboot target asks
# for - and it made "Graceful Restart" indistinguishable from a force restart.

. /usr/sbin/nxp_host_power.sh

MODE="${1:-graceful}"

case "$MODE" in
graceful)
	host_reset_graceful
	;;
force)
	host_reset_force
	;;
*)
	echo "usage: $0 [graceful|force]" >&2
	exit 1
	;;
esac

exit 0
