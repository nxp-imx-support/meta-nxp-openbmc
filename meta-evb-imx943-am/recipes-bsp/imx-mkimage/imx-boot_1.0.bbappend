# Copyright 2026 NXP
#
# Toggle between applying the Antmicro DC-SCM patches and plain upstream.
# Set AM_USE_CUSTOM_SRC in local.conf: "1" = patched (default), "0" = upstream.

AM_USE_CUSTOM_SRC ?= "1"

# Always fetch from the public GitHub tree so an external build needs no
# NXP-internal (bitbucket.sw.nxp.com) access. The Antmicro board support is
# applied as patches on top instead of living on a private branch.
IMX_MKIMAGE_SRC = "git://github.com/nxp-imx/imx-mkimage.git;protocol=https"
SRCBRANCH = "lf-6.18.2_1.0.0"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their sources to this board's commit.
SRCREV:evk-imx943-am = "c0debd7c0b4a125bd3ca66bc68f1915882b2bb62"

MKIMAGE_EXTRA_ARGS:append:evb-imx943-am = " QSPI_HEADER=./scripts/fspi_header_MT35XU2G"

# The DC-SCM patch series lives in the shared meta-nxp root layer because it is
# cumulative and covers both the LATU and Antmicro boards (0010/0012 add the
# Antmicro board and its NOR fspi header, 0013 fixes the iMX943 header).
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../recipes-bsp/imx-mkimage/files:"

SRC_URI:append = "${@' \
    file://0001-iMX94-Update-fast-hash-support-for-A1.patch \
    file://0002-iMX94-Add-XSPI-FCB-copy-image.patch \
    file://0003-Handler-i.MX94-A0-A1.patch \
    file://0004-iMX9x-Set-OEI-to-be-enabled-by-default.patch \
    file://0005-Add-fw-version-when-generating-caspule.patch \
    file://0006-LF-18073-iMX94-Add-flash_all_no_m33s-target.patch \
    file://0007-imx95-defautl-yaml.patch \
    file://0008-Add-fcb.yaml-changes-for-LATU_DCSM.patch \
    file://0009-Add-iMX943-deafult-Yaml.patch \
    file://0010-Changes-for-AntMicro-board.patch \
    file://0011-Adds-fspi-header-file-for-LATU-Nor-flash.patch \
    file://0012-Adds-fspi-header-file-for-AntMicro-Nor-flash.patch \
    file://0013-Fix-iMX943-fspi-header.patch \
    file://0014-Fix-LATU-iMX95-fspi-header.patch' if d.getVar('AM_USE_CUSTOM_SRC') == '1' else ''}"
