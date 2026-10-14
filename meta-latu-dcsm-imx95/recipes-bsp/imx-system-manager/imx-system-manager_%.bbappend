# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

# Always use GitHub upstream source.
# When LATU_USE_CUSTOM_SRC=1, LATU-specific patches are applied on top.
IMX_SYSTEM_MANAGER_SRC = "git://github.com/nxp-imx/imx-sm.git;protocol=https"
SRCBRANCH = "master"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their u-boot/SM to this board's commit.
SRCREV:latu-dcsm-imx95 = "eec232878ab7dd460f5a8f3767d39dc7e9412efa"

# The DC-SCM patch series lives in the shared meta-nxp root layer so that both
# latu-dcsm-imx95 and evb-imx943-am can apply it (the series is cumulative and
# covers both boards). Prepend it so BitBake finds these patches before the
# base layer's files/.
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../recipes-bsp/imx-system-manager/files:"

SRC_URI:append = "${@' \
    file://0001-Adds-LATU_DCSM-board-support.patch \
    file://0002-Add-System-Manager-board-port-for-the-LATU-DC-SCM.patch \
    file://0003-Add-mcimx94-dc-scm-board.patch \
    file://0004-Fix-SM-build-for-Antmicro.patch' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ''}"
