# Copyright 2025-2026 NXP

KSOC = "imx91"
KBOARD = "frdm"
KPKG = "11x11"
# KMACHINE = "${KSOC}-${KBOARD}"
CONFIG_BASENAME = "${KSOC}_${KPKG}_${KBOARD}"

BMC_LINUX_DTS = "${KSOC}-${KPKG}-${KBOARD}.dtb"

include conf/machine/include/nxp.inc
