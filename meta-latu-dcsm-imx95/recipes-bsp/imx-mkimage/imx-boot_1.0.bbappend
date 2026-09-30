# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

IMX_MKIMAGE_SRC = "${@'git://git@bitbucket.sw.nxp.com/isp/imx-mkimage-dcscm.git;protocol=ssh' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'git://github.com/nxp-imx/imx-mkimage.git;protocol=https'}"
SRCBRANCH = "${@'lf-6.18.20_2.0.0' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'lf-6.18.2_1.0.0'}"
SRCREV    = "${AUTOREV}"

MKIMAGE_EXTRA_ARGS:append:latu-dcsm-imx95 = "${@ ' QSPI_HEADER=./scripts/fspi_header_MX66U1G45G' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else ' QSPI_HEADER=./scripts/fspi_header_133'}"

# latu-dcsm-imx95 uses UBOOT_CONFIG = "sd fspi" and
# IMXBOOT_TARGETS = "flash_a55_flexspi flash_a55".
# The base imx-boot recipe builds all targets for every UBOOT_CONFIG,
# producing 4 flash.bin files. Prune the two cross-product files so
# only the correct pair is deployed:
#   sd   + flash_a55          -> for WIC SD/eMMC image
#   fspi + flash_a55_flexspi  -> for SPI NOR flat image

do_deploy:append:latu-dcsm-imx95() {
    # Remove the cross-product flash.bin files that the base recipe
    # builds (sd x flash_a55_flexspi) and (fspi x flash_a55).
    # Only keep the correct matching pairs:
    #   sd   + flash_a55          -> for WIC SD/eMMC image
    #   fspi + flash_a55_flexspi  -> for SPI NOR flat image
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_a55_flexspi"
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-fspi.bin-flash_a55"
    # Update the imx-boot symlink to point to the SD variant for WIC image use
    ln -sf "imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_a55" \
           "${DEPLOYDIR}/imx-boot"
}
