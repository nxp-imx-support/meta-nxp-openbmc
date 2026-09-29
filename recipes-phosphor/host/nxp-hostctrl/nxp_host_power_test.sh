#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# nxp_host_power_test.sh - exercise the host power logic with no hardware
#
# Runs anywhere, including the machines with no FPGA mailbox (imx93 / imx943 /
# imx95), so the graceful-vs-force decision logic can be regression-tested
# without a board and without a host.
#
# HOW THE REGISTER IS MODELLED, AND WHY IT NEEDS TWO FILES
#   The real host_ctrl register is asymmetric: a WRITE is a request (1..5) and
#   a READ returns the observed host state (0..3). debugfs can do that because
#   the driver routes the two directions to different code.
#
#   A single plain file cannot: the value 1 would mean both "power on" and
#   "host is in S0", 2 both "graceful off" and "shutting down", and so on. A
#   model built on one file therefore cannot tell a stale request from a state
#   and races against itself - which is a limitation of the harness, not of the
#   library.
#
#   So the test overrides just the two transport accessors to use separate
#   request and state files, which reproduces the real register's asymmetry
#   exactly. Everything above them - the graceful path, the polling, the
#   timeout, the escalation, the D-Bus ordering - is the library's own
#   unmodified code, and that is what is under test.
#
#   The file transport in the library is still exercised: have_espi() must
#   select it before any case runs (checked below), which is what makes this
#   usable on a mailbox-less board.
#
# Host models
#   compliant - honours a graceful request: acknowledges, sits in the
#               intermediate state, then reaches the target state on its own.
#   stubborn  - ignores graceful requests entirely, so the escalation-to-force
#               path is the thing being tested.
#
# What this does and does not prove
#   DOES     - graceful and force are distinct operations; graceful waits for
#              the host rather than assuming; it escalates on timeout; a
#              compliant host is never force-killed; CurrentHostState goes
#              TransitioningTo* first and terminal only on completion.
#   DOES NOT - that an FPGA or a real host honours the request. That needs the
#              eSPI transport on hardware.
#
# Usage: nxp_host_power_test.sh

set -u

LIB="${NXP_HOST_POWER_LIB:-/usr/sbin/nxp_host_power.sh}"
[ -r "$LIB" ] || LIB="$(dirname "$0")/nxp_host_power.sh"
[ -r "$LIB" ] || { echo "cannot find nxp_host_power.sh"; exit 1; }

WORK="$(mktemp -d)"
MODEL_PID=""
cleanup() {
	[ -n "$MODEL_PID" ] && kill "$MODEL_PID" 2>/dev/null
	rm -rf "$WORK"
}
trap cleanup EXIT

CTRL="$WORK/host_ctrl"	 # what the library sees as the register
REQ="$WORK/request"	 # write side: last request the BMC made
STATE="$WORK/state"	 # read side: observed host state
STATES="$WORK/states"	 # recorded CurrentHostState publications

echo 0 > "$REQ"
echo 1 > "$STATE"
echo 1 > "$CTRL"	 # must exist and be writable for have_espi()
: > "$STATES"

PASS=0
FAIL=0
ok()  { echo "  PASS: $*"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Load the library, then split the transport into request/state and stub D-Bus.
# ---------------------------------------------------------------------------
export NXP_HOST_CTRL_PATH="$CTRL"
export GRACEFUL_TIMEOUT=6	# keep the suite quick
export RESET_TIMEOUT=6
export POLL_INTERVAL=1
export GPIO_ASSERT_SECS=1

# shellcheck source=/dev/null
. "$LIB"

# Record which transport the library picked BEFORE overriding the accessors,
# so the detection logic is genuinely tested.
have_espi
DETECTED="$HOST_CTRL_KIND"

host_ctrl_request() { echo "$1" > "$REQ"; }
host_ctrl_state()   { cat "$STATE" 2>/dev/null; }
espi_request()      { host_ctrl_request "$@"; }
espi_state()        { host_ctrl_state "$@"; }

publish_host_state()    { echo "$1" >> "$STATES"; }
publish_os_state()      { :; }
publish_boot_progress() { :; }

states_seen() { tr '\n' ' ' < "$STATES" 2>/dev/null; }

# ---------------------------------------------------------------------------
# Host model: consumes a request, then drives the state the way a host would.
# Consuming (resetting REQ to 0) is what makes this unambiguous.
# ---------------------------------------------------------------------------
start_host_model() {
	local mode="$1" delay="${2:-2}"

	( while :; do
		r="$(cat "$REQ" 2>/dev/null)"
		[ "$r" = 0 ] || [ -z "$r" ] || {
			echo 0 > "$REQ"			# consume
			case "$r" in
			1)  sleep "$delay"; echo 1 > "$STATE" ;;
			2)  if [ "$mode" = compliant ]; then
				echo 2 > "$STATE"	# shutting down
				sleep "$delay"
				echo 0 > "$STATE"	# reached S5
			    fi ;;
			3)  echo 0 > "$STATE" ;;	# force off
			4)  if [ "$mode" = compliant ]; then
				echo 3 > "$STATE"	# resetting
				sleep "$delay"
				echo 1 > "$STATE"	# back in S0
			    fi ;;
			5)  echo 1 > "$STATE" ;;	# force reset
			esac
		}
		sleep 0.2
	  done ) &
	MODEL_PID=$!
}

stop_host_model() {
	[ -n "$MODEL_PID" ] && kill "$MODEL_PID" 2>/dev/null
	wait "$MODEL_PID" 2>/dev/null
	MODEL_PID=""
}

# Seed state, clear history, then start the model.
begin_case() {
	: > "$STATES"
	echo 0 > "$REQ"
	echo "$1" > "$STATE"
	start_host_model "$2" "${3:-2}"
}

expect_states() {
	local want="$1" got
	got="$(states_seen)"; got="${got% }"
	[ "$got" = "$want" ] && ok "state sequence: $got" \
		|| bad "state sequence: expected '$want', got '$got'"
}

expect_host() {
	local want="$1" got
	got="$(cat "$STATE")"
	[ "$got" = "$want" ] && ok "host ended in state $got" \
		|| bad "host state: expected $want, got $got"
}

saw()    { echo "$OUT" | grep -q "$1"; }
expect_log()     { saw "$1" && ok "$2" || bad "$3"; }
expect_no_log()  { saw "$1" && bad "$3" || ok "$2"; }

echo "=============================================================="
echo " nxp-hostctrl host power logic - no hardware required"
echo "=============================================================="
echo "library:   $LIB"
if [ "$DETECTED" = file ]; then
	ok "file transport detected (works on a mailbox-less board)"
else
	bad "expected the file transport, library selected '$DETECTED'"
	echo "aborting: nothing below would be meaningful"
	exit 1
fi

# -- 1 ----------------------------------------------------------------------
echo
echo "[1] Graceful shutdown, host complies"
begin_case 1 compliant 2
OUT="$(host_power_off_graceful 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_states "TransitioningToOff Off"
expect_host 0
expect_log "shut down gracefully" "took the graceful path" \
	"did not report a graceful shutdown"
expect_no_log "escalating to force" "did not escalate (host complied)" \
	"escalated to force against a compliant host"

# -- 2 ----------------------------------------------------------------------
echo
echo "[2] Graceful shutdown, host IGNORES the request"
begin_case 1 stubborn 2
OUT="$(host_power_off_graceful 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_states "TransitioningToOff Off"
expect_host 0
expect_log "escalating to force off" "escalated to force after timeout" \
	"did not escalate - a wedged host would never power off"

# -- 3 ----------------------------------------------------------------------
echo
echo "[3] Force shutdown"
begin_case 1 stubborn 2
OUT="$(host_power_off_force 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_states "TransitioningToOff Off"
expect_host 0
expect_no_log "graceful" "no graceful negotiation on the force path" \
	"force path attempted a graceful request"

# -- 4 ----------------------------------------------------------------------
echo
echo "[4] Graceful restart, host complies  (the reported failure)"
begin_case 1 compliant 2
OUT="$(host_reset_graceful 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
# A graceful restart observes the host leave S0, then come back, so it reports
# both halves: TransitioningToOff while it goes down and TransitioningToRunning
# while it comes back. Reporting only the first would leave a consumer unable
# to tell a restart from a shutdown.
expect_states "TransitioningToOff TransitioningToRunning Running"
expect_host 1
expect_log "restarted gracefully" "took the graceful path" \
	"did not report a graceful restart"
expect_no_log "escalating to force" \
	"did not escalate - this is the bug that was reported" \
	"escalated to force against a compliant host"

# -- 5 ----------------------------------------------------------------------
echo
echo "[5] Graceful restart, host IGNORES the request"
begin_case 1 stubborn 2
OUT="$(host_reset_graceful 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_host 1
expect_log "escalating to force reset" "escalated to force reset on timeout" \
	"did not escalate"

# -- 6 ----------------------------------------------------------------------
echo
echo "[6] Force restart"
begin_case 1 stubborn 2
OUT="$(host_reset_force 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_states "TransitioningToOff TransitioningToRunning Running"
expect_host 1

# -- 7 ----------------------------------------------------------------------
echo
echo "[7] Power on from S5"
begin_case 0 compliant 2
OUT="$(host_power_on 2>&1)"; stop_host_model
echo "$OUT" | sed 's/^/      | /'
expect_states "TransitioningToRunning Running"
expect_host 1

# -- 8 ----------------------------------------------------------------------
echo
echo "[8] Terminal state is not published before the transition completes"
echo "    (publishing it early is what hung the Web UI for ~5 min)"
begin_case 1 compliant 4
host_power_off_graceful >/dev/null 2>&1 &
OPPID=$!
sleep 1
MID="$(states_seen)"
wait $OPPID
stop_host_model

mid_terminal=0
mid_intermediate=0
for s in $MID; do
	[ "$s" = "Off" ] && mid_terminal=1
	[ "$s" = "TransitioningToOff" ] && mid_intermediate=1
done
if [ "$mid_intermediate" -eq 0 ]; then
	bad "no intermediate state published (saw '${MID:-<nothing>}')"
elif [ "$mid_terminal" -eq 1 ]; then
	bad "published terminal Off while the host was still shutting down"
else
	ok "mid-flight published only '${MID% }'"
fi

final_terminal=0
for s in $(states_seen); do [ "$s" = "Off" ] && final_terminal=1; done
[ "$final_terminal" -eq 1 ] \
	&& ok "terminal Off published once the host was actually down" \
	|| bad "terminal Off never published"

echo
echo "=============================================================="
printf ' passed: %d   failed: %d\n' "$PASS" "$FAIL"
echo "=============================================================="
[ "$FAIL" -eq 0 ] || exit 1
echo
echo "NOTE: validates the BMC-side decision logic only. Whether a real host"
echo "      honours a graceful request needs the eSPI transport on hardware."
exit 0
