# Copyright 2025-2026 NXP


KSOC = "imx95"
KBOARD = "frdm"
KPKG = "15x15"
# KMACHINE = "${KSOC}-${KBOARD}"
CONFIG_BASENAME = "${KSOC}_${KPKG}_${KBOARD}"

BMC_LINUX_DTS = "${KSOC}-${KPKG}-${KBOARD}.dtb"

include conf/machine/include/nxp.inc
include conf/machine/imx95-15x15-lpddr4x-frdm.conf
