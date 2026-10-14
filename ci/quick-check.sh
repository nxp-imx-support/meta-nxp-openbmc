#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP
#
# ci/quick-check.sh
#
# Fast sanity gate for meta-nxp-openbmc. Never builds anything. Per machine it
# runs two stages, the second only if the first is clean:
#
#   1. `bitbake -p`  - parse all metadata. Catches:
#        - plain BitBake syntax errors in any .bb/.bbappend/.conf/.inc
#        - stale FILESEXTRAPATHS / SRC_URI machine overrides
#        - duplicate or dangling BBFILE_COLLECTIONS / LAYERDEPENDS
#      It also resolves any ${AUTOREV} SRCREV (linux-imx, bmc_mailbox internal
#      branches) via git ls-remote as a side effect, so a break in either of
#      those surfaces here too, with no extra wiring.
#
#   2. `bitbake <target> -n` - resolve the full dependency graph for the image
#      without running any task. -p alone never resolves a target and so cannot
#      see a dependency that does not exist; -n catches:
#        - IMAGE_INSTALL / RDEPENDS naming a package nothing PROVIDES
#        - unsatisfiable or ambiguous provider resolution (duplicate RPROVIDES)
#        - DEPENDS on a recipe absent from every enabled layer
#      Gated behind QUICK_CHECK_DRYRUN (default on) because it is the slower of
#      the two and not every nightly needs it.
#
# Usage:
#   ci/quick-check.sh --nightly              <- intended Bamboo entry point
#   ci/quick-check.sh --all                  all 9 machines, unconditionally
#   ci/quick-check.sh machine1 [machine2 ..] explicit machine list
#
# RUNNING IT LOCALLY (no Bamboo, no environment setup)
#   The script works on a plain developer checkout. From the OpenBMC root, with
#   this layer checked out at ./meta-nxp:
#
#       ./meta-nxp/ci/quick-check.sh frdm-imx95
#
#   Nothing needs to be exported: every variable below has a default, and the
#   cache directories are created under ./.ci-shared if you do not point them
#   somewhere else. Use --nightly only if you actually want the
#   fetch-and-gate-on-change behaviour, since it moves meta-nxp to the branch
#   tip (detached HEAD) and would discard local work. For checking your own
#   uncommitted edits, always pass machine names instead.
#
#   Useful locally:
#       QUICK_CHECK_DRYRUN=0       parse-only, roughly 5x faster per machine
#       QUICK_CHECK_KEEP_TMP=1     keep the parse cache so re-runs are quick
#       DL_DIR=... SSTATE_DIR=...  reuse an existing build's caches (both must
#                                  already exist if you set them)
#
# --nightly mode (one fetch, explicit change gate, all-or-nothing):
#   1. `git fetch` meta-nxp-openbmc once and read the new HEAD of $NXP_BRANCH.
#   2. Compare it against the SHA recorded on the PREVIOUS run (a one-line
#      state file - see NIGHTLY_STATE_FILE below).
#   3. No change            -> print it and exit 0. Nothing else runs.
#      Change (or no history yet, i.e. first-ever run) -> run the parse+layer
#      sanity check for ALL 9 machines, then (only on success) record the new
#      HEAD so tomorrow's run compares against tonight's, not against some
#      older baseline.
#
# Required layout: run from the OpenBMC build root, with meta-nxp already
# checked out at ./meta-nxp (the repo this script lives in).
#
# Env overrides:
#   DL_DIR, SSTATE_DIR     shared caches across all machines/jobs (strongly
#                           recommended - set these to a persistent Bamboo
#                           agent-local or NFS path, NOT the build workdir)
#   OPENBMC_DIR             path to the openbmc/openbmc checkout (default: ..)
#   META_NXP_DIR            path to this repo's checkout (default: ./meta-nxp
#                           relative to OPENBMC_DIR, i.e. this script's parent)
#   NXP_BRANCH              branch to track in --nightly mode (default: wrynose)
#   NIGHTLY_STATE_FILE      where the last-seen SHA is recorded (default:
#                           $OPENBMC_DIR/.ci-shared/quick-check-last-sha.<branch>)
#                           MUST be a persistent path (NFS/agent-local), not a
#                           per-build workspace, or every run looks like "first
#                           run" and nightly gating never skips anything.
#   QUICK_CHECK_KEEP_TMP    "0" (default) = delete build/<machine>/tmp after each
#                           machine is checked, so the 9 machines cost ~nothing
#                           on disk. "1" = keep it, which makes the next run's
#                           parse much faster at the cost of roughly 0.1-0.3 GB
#                           per machine (~1-3 GB for all 9). See STORAGE below.
#   QUICK_CHECK_DRYRUN      "1" (default) = also run `bitbake <target> -n` per
#                           machine after -p passes. "0" = parse-only, which is
#                           roughly 2x faster but misses all dependency-graph
#                           errors (see stage 2 above).
#   QUICK_CHECK_TARGET      target for the -n stage (default obmc-phosphor-image)
#   PYTHON                  python interpreter for bitbake. Defaults to
#                           /usr/bin/python3.9 when present (what the Bamboo
#                           agents need - bitbake will not start with their
#                           system python3), otherwise left alone and the
#                           system python3 is used. Set this to override the
#                           detection on a non-Bamboo machine.
#
# STORAGE
#   This script never builds, so it does not populate sysroots, work dirs or
#   deploy output, and it does not download sources: BitBake resolves
#   ${AUTOREV} with `git ls-remote`, not by cloning, so the shared DL_DIR and
#   SSTATE_DIR are read-only as far as this check is concerned and do not grow.
#   The only thing written per machine is build/<machine>/{conf,tmp}, and
#   effectively all of that is the BitBake parse cache under tmp/. By default
#   that tmp/ is removed once the machine has been checked, leaving only the
#   few-KB conf/ behind. Set QUICK_CHECK_KEEP_TMP=1 to trade disk for speed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_NXP_DIR="${META_NXP_DIR:-$(dirname "$SCRIPT_DIR")}"
OPENBMC_DIR="${OPENBMC_DIR:-$(cd "$META_NXP_DIR/.." && pwd)}"
# Record whether the caller supplied these, before defaults are substituted.
DL_DIR_EXPLICIT="${DL_DIR:+yes}"
SSTATE_DIR_EXPLICIT="${SSTATE_DIR:+yes}"

DL_DIR="${DL_DIR:-$OPENBMC_DIR/.ci-shared/downloads}"
SSTATE_DIR="${SSTATE_DIR:-$OPENBMC_DIR/.ci-shared/sstate-cache}"
NXP_BRANCH="${NXP_BRANCH:-wrynose}"
NIGHTLY_STATE_FILE="${NIGHTLY_STATE_FILE:-$OPENBMC_DIR/.ci-shared/quick-check-last-sha.$NXP_BRANCH}"
QUICK_CHECK_KEEP_TMP="${QUICK_CHECK_KEEP_TMP:-0}"
QUICK_CHECK_DRYRUN="${QUICK_CHECK_DRYRUN:-1}"
QUICK_CHECK_TARGET="${QUICK_CHECK_TARGET:-obmc-phosphor-image}"

ALL_MACHINES="frdm-imx91 frdm-imx93 evk-imx93-nor evk-imx943 evk-imx943-am frdm-imx95 evk-imx95 evk-imx95-nor latu-dcsm-imx95"

# Only the state file's directory is unconditionally ours to create.
mkdir -p "$(dirname "$NIGHTLY_STATE_FILE")"

# A cache path the CALLER supplied must already exist: a typo in a hand-passed
# SSTATE_DIR should fail loudly rather than silently populate a second empty
# cache that the real build cannot find. A path we defaulted ourselves is ours
# to create, which is what lets `ci/quick-check.sh <machine>` work on a plain
# developer checkout with nothing set up.
if [ -n "$DL_DIR_EXPLICIT" ] && [ ! -d "$DL_DIR" ]; then
    echo "ERROR: DL_DIR was set but does not exist: $DL_DIR" >&2
    echo "       Point it at the cache the real build uses, or leave it unset." >&2
    exit 1
fi
if [ -n "$SSTATE_DIR_EXPLICIT" ] && [ ! -d "$SSTATE_DIR" ]; then
    echo "ERROR: SSTATE_DIR was set but does not exist: $SSTATE_DIR" >&2
    echo "       Point it at the cache the real build uses, or leave it unset." >&2
    exit 1
fi
mkdir -p "$DL_DIR" "$SSTATE_DIR"

# ---------------------------------------------------------------------------
# --nightly: fetch once, gate on change, decide the machine list
# ---------------------------------------------------------------------------
nightly_gate() {
    echo "Fetching meta-nxp-openbmc ($NXP_BRANCH)..."
    # Record the hash of this script AS IT IS NOW, before the checkout below can
    # replace it on disk. Compared after the checkout to detect a self-update.
    QUICK_CHECK_SELF_HASH="$(git -C "$META_NXP_DIR" hash-object "ci/$(basename "${BASH_SOURCE[0]}")" 2>/dev/null || echo "")"

    # Works whether meta-nxp was freshly cloned by the CI task or is a
    # persistent checkout being reused: fetch the branch explicitly and read
    # FETCH_HEAD, which does not depend on an origin/<branch> tracking ref
    # existing (a `git clone -b <branch>` may not create one usefully).
    git -C "$META_NXP_DIR" fetch origin "$NXP_BRANCH" --quiet
    local current
    current="$(git -C "$META_NXP_DIR" rev-parse FETCH_HEAD)"

    local last=""
    [ -f "$NIGHTLY_STATE_FILE" ] && last="$(cat "$NIGHTLY_STATE_FILE")"

    echo "Last checked SHA : ${last:-<none - first run>}"
    echo "Current HEAD SHA : $current"

    if [ -n "$last" ] && [ "$last" = "$current" ]; then
        echo "No change in $NXP_BRANCH since last run - skipping sanity check."
        exit 0
    fi

    echo "Change detected (or first run) - running sanity on all 9 machines."
    # Move the worktree to the exact commit we gated on, so the per-machine
    # parsing below sees precisely what was compared. --force because a reused
    # checkout may carry local modifications from a previous run.
    git -C "$META_NXP_DIR" checkout --quiet --force "$current"

    # Re-exec if this very script changed in the commit we just checked out.
    #
    # Bash reads the script from disk as it executes, but the copy already
    # parsed into memory is the OLD one: by the time the checkout above lands,
    # we are still running the version that was on disk when the CI task
    # launched us. So a run that picks up a commit which modifies
    # ci/quick-check.sh would gate on the NEW commit while executing the OLD
    # logic - and then record the new SHA as the baseline, meaning the updated
    # script silently never runs for that commit at all.
    #
    # Guard with QUICK_CHECK_REEXECED so this can only happen once per run.
    if [ -z "${QUICK_CHECK_REEXECED:-}" ]; then
        local self_rel="ci/$(basename "${BASH_SOURCE[0]}")"
        local old_hash="${QUICK_CHECK_SELF_HASH:-}"
        local new_hash
        new_hash="$(git -C "$META_NXP_DIR" hash-object "$self_rel" 2>/dev/null || echo "")"
        if [ -n "$old_hash" ] && [ -n "$new_hash" ] && [ "$old_hash" != "$new_hash" ]; then
            echo "This script changed in $current - re-executing the updated version."
            export QUICK_CHECK_REEXECED=1
            # Pass the decision forward so the new process does not re-fetch or
            # re-gate; it just runs the checks and records the baseline.
            export QUICK_CHECK_PREGATED_SHA="$current"
            exec "$META_NXP_DIR/$self_rel" --all-pregated
        fi
    fi

    MACHINES="$ALL_MACHINES"
    NIGHTLY_NEW_SHA="$current"
}

NIGHTLY_NEW_SHA=""
if [ "${1:-}" = "--nightly" ]; then
    nightly_gate
elif [ "${1:-}" = "--all-pregated" ]; then
    # Internal: we are the re-exec'd updated copy of this script. The fetch,
    # change-detection and checkout already happened in the parent process, so
    # skip straight to the checks and still record the baseline at the end.
    MACHINES="$ALL_MACHINES"
    NIGHTLY_NEW_SHA="${QUICK_CHECK_PREGATED_SHA:-}"
    echo "(running updated script for ${NIGHTLY_NEW_SHA:-unknown commit})"
elif [ "${1:-}" = "--all" ]; then
    MACHINES="$ALL_MACHINES"
elif [ "$#" -gt 0 ]; then
    MACHINES="$*"
else
    MACHINES="$ALL_MACHINES"
fi

MACHINES="$(echo "$MACHINES" | xargs -n1 | sort -u | xargs)"
echo "Machines to check: $MACHINES"

# ---------------------------------------------------------------------------
# Step 2: parse-only sanity + layer checks per machine (no fetch, no compile)
#
# The environment handling below deliberately mirrors what the existing
# OPENBMC_IMX95 daily-build job does on the Bamboo agents, because that is the
# only configuration known to work there:
#   - `source ./setup <machine>`, not openbmc-env/TEMPLATECONF. ./setup resolves
#     the machine to its vendor template itself and creates build/<machine>.
#   - PYTHON pinned to python3.9 with PYTHONHOME/PYTHONPATH unset, plus a
#     python3 symlink early in PATH. bitbake refuses to run otherwise on these
#     agents (system python3 is too old / wrongly configured).
# Both are overridable so the script still works on a normal dev machine.
# ---------------------------------------------------------------------------
cd "$OPENBMC_DIR"
overall_rc=0

# Match the daily-build job's python handling. PYTHON may be pre-set by the
# Bamboo job; only synthesise the symlink shim when we actually have a python3.9.
if [ -z "${PYTHON:-}" ] && [ -x /usr/bin/python3.9 ]; then
    PYTHON=/usr/bin/python3.9
fi
if [ -n "${PYTHON:-}" ]; then
    export PYTHON
    unset PYTHONHOME PYTHONPATH || true
    PY_SHIM_DIR="$(mktemp -d)"
    # Remove the shim on any exit path, so repeated nightly runs do not leak a
    # tmpdir each. Guarded on being set and on looking like a mktemp path.
    trap 'if [ -n "${PY_SHIM_DIR:-}" ] && [ -d "$PY_SHIM_DIR" ]; then rm -rf "$PY_SHIM_DIR"; fi' EXIT
    ln -sf "$PYTHON" "$PY_SHIM_DIR/python3"
    export PATH="$PY_SHIM_DIR:$PATH"
    echo "Using PYTHON=$PYTHON ($("$PYTHON" --version 2>&1))"
fi

for m in $MACHINES; do
    echo "=============================== $m ==============================="

    rc=0
    # ./setup must be sourced in a subshell per machine: it mutates PATH/BBPATH
    # and cds into build/<machine>, and those must not leak into the next
    # iteration. Everything for one machine therefore runs inside ( ... ).
    (
        set +u                       # ./setup and oe-init-build-env are not -u clean
        source ./setup "$m" >/dev/null 2>&1 || {
            echo "SETUP FAILED: $m"; exit 1; }

        # ./setup leaves us in the build dir for this machine.
        #
        # Inject our tuning idempotently. This script is expected to run against
        # a PERSISTENT build/<machine> directory (we deliberately do not clean
        # checkout or wipe the tree - re-fetching openbmc takes well over an
        # hour and the whole point is an incremental check), so a plain append
        # would re-add these lines on every nightly run and grow local.conf
        # without bound.
        #
        # Strip any previous block, but only when BOTH markers are present and
        # well ordered. `sed '/begin/,/end/d'` must not be used unguarded: with
        # the end marker missing - which happens if a previous run was killed
        # between writing the two markers - the range runs to EOF and silently
        # destroys every user setting below the block (verified: it empties the
        # file). Resolving both line numbers first makes the delete exact, and a
        # truncated block is left alone for a human to look at rather than
        # being "cleaned up" along with unrelated settings.
        if [ -f conf/local.conf ]; then
            qc_begin="$(grep -n '^# --- quick-check begin ---$' conf/local.conf | head -1 | cut -d: -f1)"
            qc_end="$(grep -n '^# --- quick-check end ---$'   conf/local.conf | head -1 | cut -d: -f1)"
            if [ -n "$qc_begin" ] && [ -n "$qc_end" ] && [ "$qc_end" -gt "$qc_begin" ]; then
                sed -i "${qc_begin},${qc_end}d" conf/local.conf
            elif [ -n "$qc_begin" ] || [ -n "$qc_end" ]; then
                echo "  WARNING: incomplete quick-check block in $PWD/conf/local.conf" \
                     "(begin=${qc_begin:-none} end=${qc_end:-none}); leaving it in place."
            fi
        fi
        {
            echo "# --- quick-check begin ---"
            echo "DL_DIR = \"$DL_DIR\""
            echo "SSTATE_DIR = \"$SSTATE_DIR\""
            echo "BB_NUMBER_THREADS = \"4\""
            echo "PARALLEL_MAKE = \"-j 4\""
            echo "# --- quick-check end ---"
        } >> conf/local.conf

        if ! bitbake -p > parse.log 2>&1; then
            echo "PARSE FAILED: $m"
            tail -n 60 parse.log
            exit 1
        fi

        layer_rc=0
        bitbake-layers show-layers     > layers.log 2>&1 || layer_rc=1
        bitbake-layers show-overlayed >> layers.log 2>&1 || layer_rc=1
        # May legitimately not exist on every machine - informational only.
        bitbake-layers show-recipes qspi-mailbox mock-server obmf-driver obmf-bmc-apps \
                                      >> layers.log 2>&1 || true

        # Catch duplicate BBFILE_COLLECTIONS explicitly. BitBake normally errors
        # on this during parse, but surface it clearly if it slips through.
        #
        # Parse only the table body: skip everything up to the "=====" rule
        # under the "layer / path / priority" header, and ignore any
        # NOTE:/WARNING:/ERROR: lines. bitbake-layers interleaves those on
        # stdout ("Reconnecting to bitbake server...", repeated .netrc
        # permission warnings), and a naive "skip 2 header lines" filter counted
        # the repeated log prefixes as duplicate layer names - which produced a
        # bogus "DUPLICATE LAYER COLLECTION(S): NOTE: WARNING:" failure on a
        # perfectly healthy tree.
        dup="$(bitbake-layers show-layers 2>/dev/null \
               | awk '/^=====/ { body = 1; next }
                      body && NF >= 3 && $1 !~ /^(NOTE|WARNING|ERROR):/ { print $1 }' \
               | sort | uniq -d)"
        if [ -n "$dup" ]; then
            echo "DUPLICATE LAYER COLLECTION(S): $dup"
            layer_rc=1
        fi

        if [ "$layer_rc" -ne 0 ]; then
            echo "LAYER CHECK FAILED: $m"
            cat layers.log
            exit 1
        fi

        echo "  parse + layers clean"

        # Stage 2: dependency-graph resolution for the real image target.
        #
        # `bitbake -p` only reads metadata; it never resolves a target, so it
        # structurally cannot catch a dependency that does not exist. `-n`
        # (--dry-run) builds the full task graph for the target and reports what
        # WOULD run without running it, which does catch:
        #   - IMAGE_INSTALL / RDEPENDS naming a package nothing PROVIDES
        #   - unsatisfiable or ambiguous provider resolution (multiple
        #     RPROVIDES of the same name, PREFERRED_PROVIDER missing)
        #   - DEPENDS on a recipe that is not in any enabled layer
        # Run it only after -p is clean: a -p failure is a metadata/syntax
        # problem with a much smaller error surface, and a graph failure on top
        # of a parse failure is just noise.
        if [ "$QUICK_CHECK_DRYRUN" = "1" ]; then
            if ! bitbake "$QUICK_CHECK_TARGET" -n > dryrun.log 2>&1; then
                echo "DRY-RUN FAILED: $m ($QUICK_CHECK_TARGET)"
                tail -n 60 dryrun.log
                exit 1
            fi
            echo "OK: $m (parse + layers + dry-run clean)"
        else
            echo "OK: $m (parse + layers clean; dry-run skipped)"
        fi
    ) || rc=1

    [ "$rc" -ne 0 ] && overall_rc=1

    # Reclaim the parse cache for this machine. `bitbake -p` writes only
    # build/<machine>/tmp (cache/ plus a little log), no sysroots or work dirs,
    # but across 9 machines that still adds up to a few GB that would otherwise
    # sit on the build machine forever. Dropping it keeps the whole 9-machine
    # check to a few KB of conf/ per machine; the cost is that the next run has
    # to re-parse from scratch. Set QUICK_CHECK_KEEP_TMP=1 to keep it.
    # Done outside the subshell so it runs even when that machine failed.
    if [ "$QUICK_CHECK_KEEP_TMP" != "1" ] && [ -d "build/$m/tmp" ]; then
        rm -rf "build/$m/tmp"
    fi
done

echo "==================================================================="
if [ "$overall_rc" -eq 0 ]; then
    echo "RESULT: all checked machines clean"
else
    echo "RESULT: at least one machine FAILED (see above)"
fi

# Report what this check is occupying, so growth on the build machine is
# visible in the job log rather than being discovered when the disk fills.
if [ -d build ]; then
    echo "Disk used by build/ after cleanup: $(du -sh build 2>/dev/null | cut -f1)"
fi

# Only advance the nightly baseline on a clean run. If anything failed, leave
# the state file pointing at the old SHA so tomorrow's run (and any manual
# rerun tonight) still sees "change detected" and re-checks, instead of
# silently adopting a broken commit as the new baseline.
if [ -n "$NIGHTLY_NEW_SHA" ] && [ "$overall_rc" -eq 0 ]; then
    echo "$NIGHTLY_NEW_SHA" > "$NIGHTLY_STATE_FILE"
    echo "Recorded $NIGHTLY_NEW_SHA as the new baseline in $NIGHTLY_STATE_FILE"
fi

exit $overall_rc
