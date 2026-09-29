#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# poweroff.sh - shut the host down
#
# Usage: poweroff.sh [graceful|force]
#   graceful (default) - ask the host firmware to shut itself down over the
#                        ACPI sideband, wait for it, and escalate to a force
#                        off only if it does not comply within the timeout.
#   force              - drop the host immediately, no negotiation.
#
# The mode defaults to graceful because that is what OpenBMC's
# obmc-host-shutdown@.target means: the force path has its own target
# (obmc-chassis-poweroff@.target) and its own unit. Previously this script only
# ever did an immediate drop, so a graceful shutdown request and a force
# shutdown request produced identical behaviour.

. /usr/sbin/nxp_host_power.sh

MODE="${1:-graceful}"

case "$MODE" in
graceful)
	host_power_off_graceful
	;;
force)
	host_power_off_force
	;;
*)
	echo "usage: $0 [graceful|force]" >&2
	exit 1
	;;
esac

exit 0
