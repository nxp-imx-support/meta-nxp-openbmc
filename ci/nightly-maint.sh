#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP
#
# ci/nightly-maint.sh
#
# Nightly/weekly housekeeping for the OpenBMC build machine. Deliberately
# separate from ci/quick-check.sh: that script is a fast read-only gate, this
# one reports on and prunes build state, and the two have very different
# runtimes and failure semantics.
#
# Two independent jobs, selected by subcommand:
#
#   report-history   Summarise what buildhistory recorded for the last build(s):
#                    rootfs size per machine, headroom against the NOR rootfs
#                    partition where one is defined, and the package/size delta
#                    versus the previous commit in the buildhistory git repo.
#                    Read-only. Requires that the real image build ran with
#                    buildhistory enabled (see BUILDHISTORY SETUP below).
#
#   prune-sstate     Prune the shared sstate cache with OE's own
#                    sstate-cache-management.py. Intended WEEKLY, not nightly.
#                    Nightly builds of 9 machines make this cache grow without
#                    bound; each rebuilt recipe leaves its previous signature
#                    behind forever.
#
# Usage:
#   ci/nightly-maint.sh report-history [machine ...]   (default: all machines)
#   ci/nightly-maint.sh prune-sstate [--dry-run]
#
# BUILDHISTORY SETUP (one-time, in the build job's local.conf injection)
#   buildhistory only records anything if the real image build inherits it. Add
#   to the local.conf of the *build* job (NOT this script, and not quick-check,
#   which never builds anything):
#
#       INHERIT += "buildhistory"
#       BUILDHISTORY_COMMIT = "1"
#       BUILDHISTORY_DIR = "/opt/samba/nxf62814/build/buildhistory"
#
#   BUILDHISTORY_DIR must be OUTSIDE the per-build workspace and SHARED by all
#   machines, otherwise there is no history to diff against: the whole value is
#   the night-over-night delta, and buildhistory keeps that as git commits.
#   Point BUILDHISTORY_DIR here via the same variable.
#
# Env:
#   SSTATE_DIR         shared sstate cache (required for prune-sstate)
#   BUILDHISTORY_DIR   shared buildhistory git repo (required for report-history)
#   OPENBMC_DIR        OpenBMC checkout, for locating OE's scripts/ (default: ..)
#   SSTATE_KEEP_DAYS   informational only; see the note in prune_sstate()

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_NXP_DIR="$(dirname "$SCRIPT_DIR")"
OPENBMC_DIR="${OPENBMC_DIR:-$(cd "$META_NXP_DIR/.." && pwd)}"
BUILDHISTORY_DIR="${BUILDHISTORY_DIR:-}"
SSTATE_DIR="${SSTATE_DIR:-}"

ALL_MACHINES="frdm-imx91 frdm-imx93 evk-imx93-nor evk-imx943 evk-imx943-am frdm-imx95 evk-imx95 evk-imx95-nor latu-dcsm-imx95"

# NOR rootfs partition ceiling, resolved from the machine conf at runtime.
#
# Only NOR-booting machines have a hard partition ceiling that a growing rootfs
# can silently overflow; eMMC/SD machines return 0 ("no ceiling"). Four machines
# define a NOR map today, and the headroom varies by nearly 3x - the 19 MiB one
# is the one to watch:
#   evk-imx95-nor   0x02000000 / 0x00D00000  -> 19.00 MiB rootfs
#   evk-imx93-nor      0x03B00000 / 0x01340000  -> 39.75 MiB
#   latu-dcsm-imx95     0x03A20000 / 0x011A0000  -> 40.50 MiB
#   evk-imx943-am       0x06200000 / 0x02600000  -> 60.00 MiB
# Read rather than hardcoded: the partition maps are retuned occasionally and a
# stale copy here would report false headroom.
# Returns the rootfs partition size in KB, or 0 if the machine has no NOR map.
nor_rootfs_limit_kb() {
    local machine="$1" conf size_hex off_hex
    conf="$(find "$META_NXP_DIR" -path "*/conf/machine/$machine.conf" | head -1)"
    [ -z "$conf" ] && { echo 0; return; }
    size_hex="$(grep -oP '^NOR_FLASH_SIZE\s*[?:]*=\s*"\K[0-9a-fA-Fx]+' "$conf" | tail -1 || true)"
    off_hex="$(grep -oP '^NOR_OFFSET_ROOTFS\s*[?:]*=\s*"\K[0-9a-fA-Fx]+' "$conf" | tail -1 || true)"
    if [ -z "$size_hex" ] || [ -z "$off_hex" ]; then echo 0; return; fi
    echo $(( ( $((size_hex)) - $((off_hex)) ) / 1024 ))
}

# ---------------------------------------------------------------------------
# report-history
# ---------------------------------------------------------------------------
report_history() {
    if [ -z "$BUILDHISTORY_DIR" ]; then
        echo "ERROR: BUILDHISTORY_DIR is not set." >&2
        echo "       Set it to the shared buildhistory dir used by the build job." >&2
        exit 1
    fi
    if [ ! -d "$BUILDHISTORY_DIR" ]; then
        echo "ERROR: BUILDHISTORY_DIR does not exist: $BUILDHISTORY_DIR" >&2
        echo "       The image build must run with INHERIT += \"buildhistory\"" >&2
        echo "       and BUILDHISTORY_DIR pointing there. See the header." >&2
        exit 1
    fi

    local machines="${*:-$ALL_MACHINES}"
    local rc=0

    echo "buildhistory: $BUILDHISTORY_DIR"
    echo

    printf '%-22s %12s %12s %10s\n' "MACHINE" "ROOTFS_KB" "NOR_LIMIT_KB" "HEADROOM"
    printf '%-22s %12s %12s %10s\n' "----------------------" "------------" "------------" "----------"

    for m in $machines; do
        # buildhistory lays out images/<machine>/<libc>/<image>/
        local img_dir
        img_dir="$(find "$BUILDHISTORY_DIR/images/$m" -maxdepth 2 -type d -name 'obmc-phosphor-image' 2>/dev/null | head -1 || true)"
        if [ -z "$img_dir" ]; then
            printf '%-22s %12s %12s %10s\n' "$m" "no-data" "-" "-"
            continue
        fi

        # image-info.txt carries IMAGE_ROOTFS_SIZE; files-in-image.txt is the
        # authoritative content list. Prefer the recorded rootfs size.
        local size_kb=""
        if [ -f "$img_dir/image-info.txt" ]; then
            size_kb="$(grep -oP '^IMAGE_ROOTFS_SIZE\s*=\s*\K[0-9]+' "$img_dir/image-info.txt" | tail -1 || true)"
        fi
        [ -z "$size_kb" ] && size_kb="?"

        local limit_kb
        limit_kb="$(nor_rootfs_limit_kb "$m")"

        if [ "$limit_kb" = "0" ] || [ "$size_kb" = "?" ]; then
            printf '%-22s %12s %12s %10s\n' "$m" "$size_kb" "-" "-"
            continue
        fi

        local head_kb=$(( limit_kb - size_kb ))
        local pct=$(( size_kb * 100 / limit_kb ))
        printf '%-22s %12s %12s %7s%% ' "$m" "$size_kb" "$limit_kb" "$pct"
        if [ "$head_kb" -lt 0 ]; then
            echo "OVERFLOW by $(( -head_kb )) KB"
            rc=1
        elif [ "$pct" -ge 90 ]; then
            echo "WARN (<10% free)"
        else
            echo "ok"
        fi
    done

    echo
    # Night-over-night delta. This is the main reason buildhistory is worth
    # enabling: the diff names exactly which packages appeared, vanished or
    # changed size since the previous build.
    if [ -d "$BUILDHISTORY_DIR/.git" ]; then
        echo "=== buildhistory delta vs previous commit ==="
        local prev
        prev="$(git -C "$BUILDHISTORY_DIR" rev-parse --quiet --verify 'HEAD~1' || true)"
        if [ -z "$prev" ]; then
            echo "(only one buildhistory commit so far - no delta to show yet)"
        else
            git -C "$BUILDHISTORY_DIR" log -1 --format='HEAD:  %h %ad %s' --date=short
            git -C "$BUILDHISTORY_DIR" log -1 --format='HEAD~1:%h %ad %s' --date=short HEAD~1
            echo
            # buildhistory-diff renders this far more readably than git diff.
            local bhdiff="$OPENBMC_DIR/upstream-layers/openembedded-core/scripts/buildhistory-diff"
            if [ -x "$bhdiff" ]; then
                "$bhdiff" -p "$BUILDHISTORY_DIR" HEAD~1 HEAD || true
            else
                echo "(buildhistory-diff not found at $bhdiff, falling back to git diff --stat)"
                git -C "$BUILDHISTORY_DIR" diff --stat HEAD~1 HEAD || true
            fi
        fi
    else
        echo "NOTE: $BUILDHISTORY_DIR is not a git repo."
        echo "      Set BUILDHISTORY_COMMIT = \"1\" so deltas can be diffed."
    fi

    return $rc
}

# ---------------------------------------------------------------------------
# prune-sstate
# ---------------------------------------------------------------------------
prune_sstate() {
    if [ -z "$SSTATE_DIR" ]; then
        echo "ERROR: SSTATE_DIR is not set." >&2
        exit 1
    fi
    if [ ! -d "$SSTATE_DIR" ]; then
        echo "ERROR: SSTATE_DIR does not exist: $SSTATE_DIR" >&2
        exit 1
    fi

    local mgmt="$OPENBMC_DIR/upstream-layers/openembedded-core/scripts/sstate-cache-management.py"
    if [ ! -x "$mgmt" ]; then
        echo "ERROR: sstate-cache-management.py not found/executable at:" >&2
        echo "       $mgmt" >&2
        exit 1
    fi

    echo "sstate cache: $SSTATE_DIR"
    echo "size before : $(du -sh "$SSTATE_DIR" 2>/dev/null | cut -f1)"
    echo

    # --remove-duplicated keeps only the newest sstate file per package and
    # drops superseded signatures; --remove-orphans drops siginfo files with no
    # corresponding sstate object. Together these are the safe prune: they never
    # remove the current signature, so the next build still gets full cache
    # hits. Anything more aggressive (age-based deletion) risks evicting
    # still-valid entries and turning the next nightly into a cold build, which
    # is why SSTATE_KEEP_DAYS is deliberately NOT implemented here.
    local extra=()
    if [ "${1:-}" = "--dry-run" ]; then
        echo "(dry run - nothing will be deleted)"
        extra+=("--dry-run")
    else
        extra+=("--yes")
    fi

    "$mgmt" --cache-dir="$SSTATE_DIR" --remove-duplicated -j 8 "${extra[@]}" || {
        echo "WARNING: --remove-duplicated pass returned non-zero" >&2
    }
    "$mgmt" --cache-dir="$SSTATE_DIR" --remove-orphans -j 8 "${extra[@]}" || {
        echo "WARNING: --remove-orphans pass returned non-zero" >&2
    }

    echo
    echo "size after  : $(du -sh "$SSTATE_DIR" 2>/dev/null | cut -f1)"
}

# ---------------------------------------------------------------------------
case "${1:-}" in
    report-history) shift; report_history "$@" ;;
    prune-sstate)   shift; prune_sstate "$@" ;;
    *)
        echo "usage: $(basename "$0") report-history [machine ...]" >&2
        echo "       $(basename "$0") prune-sstate [--dry-run]" >&2
        exit 2
        ;;
esac
