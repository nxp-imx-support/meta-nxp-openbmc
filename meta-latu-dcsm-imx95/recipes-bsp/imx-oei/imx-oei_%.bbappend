# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

# Always use GitHub upstream source.
# When LATU_USE_CUSTOM_SRC=1, LATU-specific patches are applied on top.
IMX_OEI_SRC = "git://github.com/nxp-imx/imx-oei.git;protocol=https"
SRCBRANCH = "master"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their sources to this board's commit.
SRCREV:latu-dcsm-imx95 = "9aea3350e643da86081c9dfaf3a6e1a84a583bfd"

# Prepend our layer's files/ so BitBake finds our patches before the base layer's files/.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = "${@' file://0001-Create-files-for-new-board-mx95-latu-dcscm-lp5x.patch' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ''}"
