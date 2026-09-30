# Copyright 2026 NXP

IMX_MKIMAGE_SRC = "git://git@bitbucket.sw.nxp.com/isp/imx-mkimage-dcscm.git;protocol=ssh"
SRCBRANCH = "lf-6.18.20_2.0.0"
SRCREV = "${AUTOREV}"

MKIMAGE_EXTRA_ARGS:append:evb-imx943-am = " QSPI_HEADER=./scripts/fspi_header_MT35XU2G"
