# Copyright 2026 NXP
#
# Toggle between applying the Antmicro DC-SCM patches and plain upstream.
# Set AM_USE_CUSTOM_SRC in local.conf: "1" = patched (default), "0" = upstream.

AM_USE_CUSTOM_SRC ?= "1"

# Always fetch from the public GitHub tree so an external build needs no
# NXP-internal (bitbucket.sw.nxp.com) access. The Antmicro board support is
# applied as patches on top instead of living on a private branch.
IMX_SYSTEM_MANAGER_SRC = "git://github.com/nxp-imx/imx-sm.git;protocol=https"
SRCBRANCH = "master"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their u-boot/SM to this board's commit.
SRCREV:evk-imx943-am = "eec232878ab7dd460f5a8f3767d39dc7e9412efa"

# The DC-SCM patch series lives in the shared meta-nxp root layer because it is
# cumulative and covers both the LATU and Antmicro boards (0003 adds the
# mcimx94 DC-SCM board, 0004 fixes the SM build for Antmicro).
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../recipes-bsp/imx-system-manager/files:"

SRC_URI:append = "${@' \
    file://0001-Adds-LATU_DCSM-board-support.patch \
    file://0002-Add-System-Manager-board-port-for-the-LATU-DC-SCM.patch \
    file://0003-Add-mcimx94-dc-scm-board.patch \
    file://0004-Fix-SM-build-for-Antmicro.patch' if d.getVar('AM_USE_CUSTOM_SRC') == '1' else ''}"
