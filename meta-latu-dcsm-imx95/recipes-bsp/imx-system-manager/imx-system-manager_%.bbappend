# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

# Always use GitHub upstream source.
# When LATU_USE_CUSTOM_SRC=1, LATU-specific patches are applied on top.
IMX_SYSTEM_MANAGER_SRC = "git://github.com/nxp-imx/imx-sm.git;protocol=https"
SRCBRANCH = "master"
SRCREV = "eec232878ab7dd460f5a8f3767d39dc7e9412efa"

# Prepend our layer's files/ so BitBake finds our patches before the base layer's files/.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = "${@' \
    file://0001-Adds-LATU_DCSM-board-support.patch \
    file://0002-Add-System-Manager-board-port-for-the-LATU-DC-SCM.patch \
    file://0003-Add-mcimx94-dc-scm-board.patch \
    file://0004-Fix-SM-build-for-Antmicro.patch' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ''}"
