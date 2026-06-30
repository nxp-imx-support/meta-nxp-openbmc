# Copyright 2025-2026 NXP

KSOC = "imx943"
KBOARD = "evk"
KPKG = "15x15"
# KMACHINE = "${KSOC}-${KBOARD}"
CONFIG_BASENAME = "${KSOC}_${KPKG}_${KBOARD}"

BMC_LINUX_DTS = "${KSOC}-evk.dtb"

include conf/machine/include/nxp.inc
