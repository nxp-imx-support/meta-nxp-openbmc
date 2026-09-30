# Copyright 2026 NXP

UBOOT_SRC = "git://git@bitbucket.sw.nxp.com/isp/uboot-imx-dcscm.git;protocol=ssh"
SRCBRANCH = "lf_v2026.04"
SRCREV = "${AUTOREV}"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:evb-imx943-am = " \
    file://0001-Fix-ethenet-nodes-for-Antmicro.patch \
"
