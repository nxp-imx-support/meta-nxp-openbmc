# Copyright 2026 NXP
#
# Toggle between applying the Antmicro DC-SCM patches and plain upstream.
# Set AM_USE_CUSTOM_SRC in local.conf: "1" = patched (default), "0" = upstream.

AM_USE_CUSTOM_SRC ?= "1"

# Always fetch from the public GitHub tree so an external build needs no
# NXP-internal (bitbucket.sw.nxp.com) access. The Antmicro board support is
# applied as patches on top instead of living on a private branch.
UBOOT_SRC = "git://github.com/nxp-imx/uboot-imx.git;protocol=https"
SRCBRANCH = "lf_v2026.04"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their u-boot/SM to this board's commit.
SRCREV:evk-imx943-am = "bb41975aeb4cbd153b49c9fd62da1d64cd65968d"

# This layer's own files/ for the Antmicro ethernet fix; the DC-SCM u-boot
# patch series lives in the shared meta-nxp root layer because it is cumulative
# and covers both the LATU and Antmicro boards (0001/0003 add and port the
# imx943-dc-scm DTS, which is the Antmicro board).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../recipes-bsp/u-boot/files/dcscm-patches:"

SRC_URI:append = "${@' \
    file://0001-arch-arm-dts-add-imx943-dc-scm-dtb-and-u-boot.dtsi.patch \
    file://0002-Adds-LATU_DCSM-base-DTS-file.patch \
    file://0003-Port-the-imx943-dc-scm-dtsi-for-2026.04.patch' if d.getVar('AM_USE_CUSTOM_SRC') == '1' else ''}"

SRC_URI:append:evb-imx943-am = " \
    file://0001-Fix-ethenet-nodes-for-Antmicro.patch \
"
