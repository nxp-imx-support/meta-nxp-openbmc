# imx-boot_%.bbappend for evb-imx93-nor
#
# Override the compile loop so each UBOOT_CONFIG variant only builds
# its matching mkimage target:
#   sd   -> flash_singleboot          (for the SD/eMMC WIC image)
#   fspi -> flash_singleboot_flexspi  (for the SPI NOR flat image)
#
# Without this, the base recipe builds all IMXBOOT_TARGETS for every
# UBOOT_CONFIG, producing 4 flash.bin files instead of 2.

# Per-config mkimage target mapping
IMXBOOT_TARGETS_sd   = "flash_singleboot"
IMXBOOT_TARGETS_fspi = "flash_singleboot_flexspi"

do_deploy:append:evb-imx93-nor() {
    # Remove the cross-product flash.bin files that the base recipe builds:
    #   (sd x flash_singleboot_flexspi) and (fspi x flash_singleboot).
    # Only keep the correct matching pairs:
    #   sd   + flash_singleboot          -> for WIC SD/eMMC image
    #   fspi + flash_singleboot_flexspi  -> for SPI NOR flat image
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_singleboot_flexspi"
    rm -f "${DEPLOYDIR}/imx-boot${BOOT_VARIANT}-${MACHINE}-fspi.bin-flash_singleboot"
    # Update the imx-boot symlink to point to the SD variant for WIC image use
    ln -sf "imx-boot${BOOT_VARIANT}-${MACHINE}-sd.bin-flash_singleboot" \
           "${DEPLOYDIR}/imx-boot"
}
