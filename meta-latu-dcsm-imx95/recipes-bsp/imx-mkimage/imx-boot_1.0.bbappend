# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

# Always use GitHub upstream source.
# When LATU_USE_CUSTOM_SRC=1, LATU-specific patches are applied on top.
IMX_MKIMAGE_SRC = "git://github.com/nxp-imx/imx-mkimage.git;protocol=https"
SRCBRANCH = "lf-6.18.2_1.0.0"
# Scoped to this machine: a bare SRCREV in a %.bbappend applies to every
# machine built from a build dir that includes this layer, which would
# silently pin their sources to this board's commit.
SRCREV:latu-dcsm-imx95 = "c0debd7c0b4a125bd3ca66bc68f1915882b2bb62"

MKIMAGE_EXTRA_ARGS:append:latu-dcsm-imx95 = "${@ ' QSPI_HEADER=./scripts/fspi_header_MX66U1G45G' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ' QSPI_HEADER=./scripts/fspi_header_133'}"

# latu-dcsm-imx95 uses UBOOT_CONFIG = "sd fspi" and
# IMXBOOT_TARGETS = "flash_a55_flexspi flash_a55".
# The base imx-boot recipe builds all targets for every UBOOT_CONFIG,
# producing 4 flash.bin files. Prune the two cross-product files so
# only the correct pair is deployed:
#   sd   + flash_a55          -> for WIC SD/eMMC image
#   fspi + flash_a55_flexspi  -> for SPI NOR flat image

do_deploy:append:latu-dcsm-imx95() {
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_a55_flexspi"
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-fspi.bin-flash_a55"
    ln -sf "imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_a55" \
           "${DEPLOYDIR}/imx-boot"
}

# The DC-SCM patch series lives in the shared meta-nxp root layer so that both
# latu-dcsm-imx95 and evk-imx943-am can apply it (the series is cumulative and
# covers both boards). Prepend it so BitBake finds these patches before the
# base layer's files/.
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
    file://0014-Fix-LATU-iMX95-fspi-header.patch' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ''}"
