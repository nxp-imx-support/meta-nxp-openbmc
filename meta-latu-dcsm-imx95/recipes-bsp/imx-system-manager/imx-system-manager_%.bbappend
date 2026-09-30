# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

IMX_SYSTEM_MANAGER_SRC = "${@'git://git@bitbucket.sw.nxp.com/isp/imx-sm.git;protocol=ssh' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'git://github.com/nxp-imx/imx-sm.git;protocol=https'}"
SRCBRANCH = "${@'latu_dcsm' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'master'}"
SRCREV    = "${AUTOREV}"
