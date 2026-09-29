#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# nxp_host_check.sh - reconcile published host state with observed host state
#
# Runs at BMC start to make sure CurrentHostState reflects the host as it
# actually is, rather than whatever was last written before the BMC rebooted.
#
# The previous version slept a flat 60 seconds and then unconditionally
# declared the host Running and drove the enable line high - so a BMC reboot
# would silently power the host on and report it up even if it was off or
# wedged. Here we look at the host first and only publish what we can see.

. /usr/sbin/nxp_host_power.sh

# Give the mailbox driver and the state services a moment to come up so the
# first observation is meaningful.
sleep 5

if have_espi; then
	st="$(espi_state)"
	case "$st" in
	"$HOST_STATE_S0")
		log "host observed Running"
		publish_boot_progress OSRunning
		publish_os_state Standby
		publish_host_state Running
		;;
	"$HOST_STATE_S5")
		log "host observed Off"
		publish_boot_progress Unspecified
		publish_os_state Inactive
		publish_host_state Off
		;;
	"$HOST_STATE_SHUTTING_DOWN"|"$HOST_STATE_RESETTING")
		# Mid-transition. Report the intermediate state and let the
		# host settle; do not force a terminal state on it.
		log "host mid-transition (state ${st}), waiting"
		publish_host_state TransitioningToRunning
		if wait_for_espi_state "$HOST_STATE_S0" "$RESET_TIMEOUT"; then
			publish_boot_progress OSRunning
			publish_os_state Standby
			publish_host_state Running
		else
			log "host did not settle within ${RESET_TIMEOUT}s"
			publish_host_state Off
		fi
		;;
	*)
		log "host state unreadable (got '${st}'), leaving published state alone"
		;;
	esac
	exit 0
fi

# GPIO-only fallback: there is no way to observe the host, so we must not
# invent a state. Leave whatever phosphor-state-manager decided in place and
# say why.
log "no eSPI sideband available - cannot observe host, leaving published state unchanged"

exit 0
