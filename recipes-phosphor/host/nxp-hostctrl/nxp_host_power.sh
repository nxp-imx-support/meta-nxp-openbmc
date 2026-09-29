#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# nxp_host_power.sh - shared host power-control library for nxp-hostctrl
#
# Sourced by the poweron / poweroff / reboot scripts. Provides one place for
# the three things the old per-script copies each got wrong:
#
#   1. GRACEFUL vs FORCE are genuinely different operations.
#      A force request drops the host immediately. A graceful request asks the
#      host firmware to shut itself down (ACPI sideband) and then WAITS for the
#      host to actually go down, escalating to force only on timeout. The old
#      scripts implemented both as the same immediate GPIO drop, which is why
#      "Graceful Restart" behaved as a force restart and why the graceful
#      shutdown appeared to do nothing.
#
#   2. Line assertion must persist.
#      libgpiod v1 gpioset releases the line as soon as it exits, so the level
#      afterwards is driver-dependent and not guaranteed to hold - a one-shot
#      "gpioset 0 2=0" is not a reliable way to hold a host down or to time a
#      reset pulse. We hold the line explicitly for a defined duration with
#      --mode=signal and release it only when the pulse is meant to end.
#
#   3. Host state must be OBSERVED, not asserted.
#      The old scripts wrote CurrentHostState themselves, immediately, before
#      the operation had happened - so the property said "Running" while the
#      host was still rebooting. phosphor-state-manager and bmcweb then waited
#      for a transition they could no longer see, which is the ~5 minute
#      "power operation in progress" hang in the Web UI. Here we publish the
#      intermediate TransitioningTo* state, poll for real completion, and only
#      publish the terminal state once the transition is genuinely done.
#
# Transport preference
#   eSPI (preferred) - the FPGA drives the host power sequencing signals and
#       reports the observed host power state back, so a graceful request goes
#       out over the ACPI sideband (SLP_S5 / reset-warning) and the host
#       firmware runs its own shutdown path.
#   file             - any writable file with the same one-byte semantics,
#       named by NXP_HOST_CTRL_PATH. Lets the graceful logic run on machines
#       with no FPGA mailbox (imx93 / imx943 / imx95) and in automated tests.
#       Same code path as eSPI, so it genuinely exercises the request/poll/
#       escalate decisions; it just does not prove the FPGA obeys them.
#   GPIO (fallback)  - a single enable/reset line. There is no sideband to ask
#       the host politely and no way to observe it, so a "graceful" request
#       degrades to a best-effort settle delay before the line is dropped. The
#       behaviour is announced in the journal so the degradation is visible
#       rather than silent.
#
# Set NXP_HOST_CTRL_PATH (e.g. in a systemd drop-in) to pick the file backend.
# See nxp_host_power_test.sh for a no-hardware exercise of all four actions.

HOST_INSTANCE="${HOST_INSTANCE:-0}"

# -- Tunables ---------------------------------------------------------------
# How long to let the host shut itself down before we stop being polite.
GRACEFUL_TIMEOUT="${GRACEFUL_TIMEOUT:-60}"
# How long to wait for the host to come back up after a reset.
RESET_TIMEOUT="${RESET_TIMEOUT:-90}"
# How long to hold the GPIO line asserted for a force off / reset pulse.
GPIO_ASSERT_SECS="${GPIO_ASSERT_SECS:-2}"
# Poll interval while waiting for a transition to complete.
POLL_INTERVAL="${POLL_INTERVAL:-2}"

# -- GPIO fallback wiring ---------------------------------------------------
# gpiochip 0 line 2 is the host enable / reset-release line on the iMX9 FRDM
# boards: driven high the host runs, held low it is held down. bmc-console
# pulses the same line low-then-high to bring the host out of reset, so the
# polarity here must match that.
GPIO_CHIP="${GPIO_CHIP:-0}"
GPIO_LINE="${GPIO_LINE:-2}"

# -- eSPI host-control register --------------------------------------------
# Request codes written to the eSPI host_ctrl register.
readonly HOST_CTRL_ON=1
readonly HOST_CTRL_GRACEFUL_OFF=2
readonly HOST_CTRL_FORCE_OFF=3
readonly HOST_CTRL_GRACEFUL_RST=4
readonly HOST_CTRL_FORCE_RST=5

# Observed host power states read back from the same register.
readonly HOST_STATE_S5=0		# off
readonly HOST_STATE_S0=1		# running
readonly HOST_STATE_SHUTTING_DOWN=2
readonly HOST_STATE_RESETTING=3

HOST_OBJ="/xyz/openbmc_project/state/host${HOST_INSTANCE}"
HOST_SVC="xyz.openbmc_project.State.Host"

log() { echo "nxp-hostctrl: $*"; }

# ---------------------------------------------------------------------------
# Transport detection
#
# The host-control transport is anything that can carry a power request and
# report the resulting host power state back. Two backends provide that:
#
#   eSPI debugfs - the real thing. The FPGA drives the ACPI sideband and
#                  reports the observed host state.
#   plain file   - a writable file with the same one-byte semantics, named by
#                  NXP_HOST_CTRL_PATH. Used on machines with no FPGA mailbox
#                  (imx93 / imx943 / imx95) to exercise the graceful logic,
#                  and for automated tests.
#
# Both are read/written identically, so the graceful path, the polling and the
# escalation-on-timeout are the SAME code in both cases - which is the point.
# A file-backed run therefore tests the decision logic for real; what it does
# not test is whether the FPGA honours the request.
# ---------------------------------------------------------------------------

# Locate the eSPI host_ctrl debugfs file, if the mailbox driver exposed one.
# Echoes the path and returns 0 when found; returns 1 otherwise.
espi_host_ctrl_path() {
	local p
	for p in /sys/kernel/debug/imx9-qspi-espi/*/host_ctrl \
		 /sys/kernel/debug/imx9-qspi-mailbox/espi/*/host_ctrl; do
		[ -e "$p" ] && { echo "$p"; return 0; }
	done
	return 1
}

# True when a host-control transport is usable. Cached so the scripts can call
# this freely without re-globbing debugfs on every poll iteration.
#
# NXP_HOST_CTRL_PATH takes precedence when set, so a test or a mailbox-less
# board can point this at a file. HOST_CTRL_KIND records which backend won so
# the logs say plainly what is driving the host.
ESPI_PATH=""
ESPI_CHECKED=0
HOST_CTRL_KIND="none"
have_espi() {
	if [ "$ESPI_CHECKED" -eq 0 ]; then
		ESPI_CHECKED=1
		if [ -n "$NXP_HOST_CTRL_PATH" ] && [ -w "$NXP_HOST_CTRL_PATH" ]; then
			ESPI_PATH="$NXP_HOST_CTRL_PATH"
			HOST_CTRL_KIND="file"
		elif ESPI_PATH="$(espi_host_ctrl_path)"; then
			HOST_CTRL_KIND="espi"
		else
			ESPI_PATH=""
			HOST_CTRL_KIND="none"
		fi
	fi
	[ -n "$ESPI_PATH" ]
}

# Write a request code to the host_ctrl register.
host_ctrl_request() {
	local req="$1"
	have_espi || return 1
	echo "$req" > "$ESPI_PATH" 2>/dev/null
}

# Read the observed host power state. Echoes a decimal state code on success.
#
# Accepts both the driver's "0x%02x" debugfs formatting and a plain decimal,
# so the file backend can be written with a bare "echo 1 > ...".
host_ctrl_state() {
	local raw
	have_espi || return 1
	raw="$(cat "$ESPI_PATH" 2>/dev/null)" || return 1
	raw="${raw%%[!0-9a-fA-FxX]*}"
	[ -n "$raw" ] || return 1
	printf '%d' "$raw" 2>/dev/null
}

# Back-compat aliases. The operations below were written against the eSPI
# names; keep them working so the naming change is not a behavioural change.
espi_request() { host_ctrl_request "$@"; }
espi_state()   { host_ctrl_state "$@"; }

# ---------------------------------------------------------------------------
# GPIO fallback
# ---------------------------------------------------------------------------

# Hold the host line at $1 (0 or 1) for $2 seconds, then release it.
#
# gpioset in libgpiod v1 drops the line as soon as it exits, so a bare
# "gpioset 0 2=0" gives an assertion of essentially zero width - not enough to
# be seen as a reset, and not enough to hold the host down. --mode=signal keeps
# the process alive holding the line until it is signalled, which is what
# actually produces a pulse of a defined width.
#
# We background it with & rather than gpioset's own --background flag: with
# --background gpioset daemonises itself, so $! would capture the short-lived
# parent rather than the process actually holding the line and the kill below
# would miss it.
gpio_hold() {
	local value="$1" secs="$2" pid

	command -v gpioset >/dev/null 2>&1 || {
		log "gpioset not available, cannot drive host line"
		return 1
	}

	gpioset --mode=signal "$GPIO_CHIP" "${GPIO_LINE}=${value}" \
		2>/dev/null &
	pid=$!

	sleep "$secs"

	# Releasing the line is what ends the pulse.
	kill "$pid" 2>/dev/null
	wait "$pid" 2>/dev/null
	return 0
}

# Release the host line, letting it return to its unforced level.
#
# Named for what it actually does, not for what one might want it to do.
# gpioset in libgpiod v1 owns the line only while it runs, so a bare
#
#     gpioset 0 2=1
#
# drives the value for microseconds and then hands the line back as an input.
# The previous name and comment here claimed this left the line "there (steady
# state)", which it never did - see the same trap documented on gpio_hold().
#
# Holding a level for real needs a process that stays alive for as long as the
# level must persist. That cannot be done from these scripts: every unit that
# calls them is Type=oneshot, so systemd reaps the whole cgroup - including any
# backgrounded gpioset - the moment the script returns. A persistent level
# therefore needs either a long-lived unit that owns the line for the duration,
# or a pin whose hardware default is the wanted level.
#
# That is acceptable here because the GPIO path is the fallback for boards with
# no eSPI sideband, and on those the line is a momentary power button: the host
# power controller latches on the edge that gpio_hold() produces, so what
# matters is the pulse, not the level afterwards. Releasing the line is the
# correct end state for a button.
#
# The $1 argument is ignored and kept only so the call sites read as before;
# there is no level to select when the only real action is "let go".
gpio_release() {
	local _value="$1"	# ignored - see above

	command -v gpioset >/dev/null 2>&1 || return 1

	# Take the line briefly and drop it again. The point is the release, which
	# happens when gpioset exits; nothing here can outlive this function.
	gpioset "$GPIO_CHIP" "${GPIO_LINE}=${_value}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# D-Bus state publication
#
# We publish what we can legitimately observe, in the order the consumers
# expect. CurrentHostState gets the intermediate TransitioningTo* value while
# the operation is in flight and the terminal value only once it has actually
# completed - publishing the terminal value up front is what left the Web UI
# spinning on "power operation in progress".
# ---------------------------------------------------------------------------

set_prop() {
	local iface="$1" prop="$2" val="$3"
	busctl set-property "$HOST_SVC" "$HOST_OBJ" "$iface" "$prop" s "$val" \
		2>/dev/null
}

publish_host_state() {
	set_prop "$HOST_SVC" CurrentHostState \
		"xyz.openbmc_project.State.Host.HostState.$1"
}

publish_os_state() {
	set_prop xyz.openbmc_project.State.OperatingSystem.Status \
		OperatingSystemState \
		"xyz.openbmc_project.State.OperatingSystem.Status.OSStatus.$1"
}

publish_boot_progress() {
	set_prop xyz.openbmc_project.State.Boot.Progress BootProgress \
		"xyz.openbmc_project.State.Boot.Progress.ProgressStages.$1"
}

# Read CurrentHostState, stripped down to the bare state name.
current_host_state() {
	busctl get-property "$HOST_SVC" "$HOST_OBJ" "$HOST_SVC" \
		CurrentHostState 2>/dev/null |
		sed -e 's/.*HostState\.//' -e 's/"//g'
}

# ---------------------------------------------------------------------------
# Wait helpers
# ---------------------------------------------------------------------------

# Wait until the eSPI-observed host state equals $1, up to $2 seconds.
# Returns 0 if reached, 1 on timeout. Returns 1 immediately without eSPI,
# since without the sideband there is nothing to observe.
wait_for_espi_state() {
	local want="$1" timeout="$2" waited=0 st

	have_espi || return 1

	while [ "$waited" -lt "$timeout" ]; do
		st="$(espi_state)" || st=""
		[ "$st" = "$want" ] && return 0
		sleep "$POLL_INTERVAL"
		waited=$((waited + POLL_INTERVAL))
	done
	return 1
}

# Wait until the observed host state STOPS being $1, up to $2 seconds.
# Returns 0 once it differs, 1 on timeout.
#
# Needed for restart: the host starts and ends a reset in the same state (S0),
# so "did it restart?" cannot be answered by waiting for S0 - that is already
# true. Confirming it left S0 first is what distinguishes a real restart from a
# request the host ignored.
wait_while_espi_state() {
	local unwanted="$1" timeout="$2" waited=0 st

	have_espi || return 1

	while [ "$waited" -lt "$timeout" ]; do
		st="$(espi_state)" || st=""
		[ -n "$st" ] && [ "$st" != "$unwanted" ] && return 0
		sleep "$POLL_INTERVAL"
		waited=$((waited + POLL_INTERVAL))
	done
	return 1
}

# ---------------------------------------------------------------------------
# Public operations
# ---------------------------------------------------------------------------

# Power the host on and only report Running once it is actually up.
host_power_on() {
	log "powering on host${HOST_INSTANCE}"

	publish_host_state TransitioningToRunning
	publish_os_state Inactive

	if have_espi; then
		espi_request "$HOST_CTRL_ON"
		if wait_for_espi_state "$HOST_STATE_S0" "$RESET_TIMEOUT"; then
			log "host reached S0"
		else
			log "host did not report S0 within ${RESET_TIMEOUT}s"
		fi
	else
		# No sideband: release the line and give the host a settle
		# window before claiming it is up.
		gpio_release 1
		sleep 3
	fi

	publish_boot_progress OSRunning
	publish_os_state Standby
	publish_host_state Running
	log "host${HOST_INSTANCE} is Running"
}

# Immediately remove host power. No negotiation, no waiting on the host.
host_power_off_force() {
	log "force powering off host${HOST_INSTANCE}"

	publish_host_state TransitioningToOff

	if have_espi; then
		espi_request "$HOST_CTRL_FORCE_OFF"
		wait_for_espi_state "$HOST_STATE_S5" 15
	else
		gpio_hold 0 "$GPIO_ASSERT_SECS"
		gpio_release 0
	fi

	publish_boot_progress Unspecified
	publish_os_state Inactive
	publish_host_state Off
	log "host${HOST_INSTANCE} is Off"
}

# Ask the host to shut itself down, wait for it, escalate to force on timeout.
host_power_off_graceful() {
	log "requesting graceful shutdown of host${HOST_INSTANCE}"

	publish_host_state TransitioningToOff

	if have_espi; then
		log "using ${HOST_CTRL_KIND} host-control transport"
		espi_request "$HOST_CTRL_GRACEFUL_OFF"
		if wait_for_espi_state "$HOST_STATE_S5" "$GRACEFUL_TIMEOUT"; then
			log "host shut down gracefully"
			publish_boot_progress Unspecified
			publish_os_state Inactive
			publish_host_state Off
			return 0
		fi
		log "graceful shutdown timed out after ${GRACEFUL_TIMEOUT}s, escalating to force off"
		espi_request "$HOST_CTRL_FORCE_OFF"
		wait_for_espi_state "$HOST_STATE_S5" 15
	else
		# Degraded path: there is no ACPI sideband on the GPIO-only
		# wiring, so we cannot ask the host to shut down and cannot
		# observe whether it did. Give it a settle window, then drop
		# the line. Say so plainly rather than pretending this was a
		# negotiated shutdown.
		log "no eSPI sideband available - graceful shutdown degrades to a timed drop"
		publish_os_state Inactive
		sleep 5
		gpio_hold 0 "$GPIO_ASSERT_SECS"
		gpio_release 0
	fi

	publish_boot_progress Unspecified
	publish_os_state Inactive
	publish_host_state Off
	log "host${HOST_INSTANCE} is Off"
}

# Reset the host without dropping chassis power, no negotiation.
host_reset_force() {
	log "force resetting host${HOST_INSTANCE}"

	publish_host_state TransitioningToOff
	publish_os_state Inactive
	publish_boot_progress Unspecified

	if have_espi; then
		espi_request "$HOST_CTRL_FORCE_RST"
	else
		# Pulse the line: hold it asserted long enough to be seen as a
		# reset, then release so the host comes back up.
		gpio_hold 0 "$GPIO_ASSERT_SECS"
		gpio_release 1
	fi

	publish_host_state TransitioningToRunning

	if have_espi; then
		wait_for_espi_state "$HOST_STATE_S0" "$RESET_TIMEOUT" ||
			log "host did not report S0 within ${RESET_TIMEOUT}s"
	else
		sleep 5
	fi

	publish_boot_progress OSRunning
	publish_os_state Standby
	publish_host_state Running
	log "host${HOST_INSTANCE} is Running"
}

# Ask the host to restart itself, wait for it, escalate to force on timeout.
host_reset_graceful() {
	log "requesting graceful restart of host${HOST_INSTANCE}"

	publish_host_state TransitioningToOff
	publish_os_state Inactive

	if have_espi; then
		log "using ${HOST_CTRL_KIND} host-control transport"
		espi_request "$HOST_CTRL_GRACEFUL_RST"

		# A restart must be confirmed by observing the host LEAVE S0
		# first. Waiting only for S0 is wrong: the host is already in
		# S0 when the request is made, so that test passes instantly
		# whether or not the host ever restarted - a host that ignores
		# the request entirely would be reported as "restarted
		# gracefully" while it kept running untouched.
		#
		# So wait for departure (any non-S0 state: RESETTING, or a
		# transient S5 as it cycles) and only then wait for the return
		# to S0. If it never leaves, the host is not honouring the
		# request and we escalate.
		if wait_while_espi_state "$HOST_STATE_S0" "$GRACEFUL_TIMEOUT"; then
			# It began restarting; now let it come back.
			publish_host_state TransitioningToRunning
			if wait_for_espi_state "$HOST_STATE_S0" \
					       "$RESET_TIMEOUT"; then
				log "host restarted gracefully"
				publish_boot_progress OSRunning
				publish_os_state Standby
				publish_host_state Running
				return 0
			fi
			log "host began restarting but did not return to S0 within ${RESET_TIMEOUT}s, escalating to force reset"
		else
			log "host did not begin restarting within ${GRACEFUL_TIMEOUT}s, escalating to force reset"
		fi
		host_reset_force
		return 0
	fi

	log "no eSPI sideband available - graceful restart degrades to a timed reset"
	publish_boot_progress Unspecified
	sleep 5
	gpio_hold 0 "$GPIO_ASSERT_SECS"
	gpio_release 1

	publish_host_state TransitioningToRunning
	sleep 5
	publish_boot_progress OSRunning
	publish_os_state Standby
	publish_host_state Running
	log "host${HOST_INSTANCE} is Running"
}
