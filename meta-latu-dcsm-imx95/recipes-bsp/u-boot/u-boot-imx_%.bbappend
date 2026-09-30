# Copyright 2026 NXP
#
# Toggle between LATU custom NXP-internal sources and upstream github defaults.
# Set LATU_USE_CUSTOM_SRC in local.conf: "1" = custom (default), "0" = upstream.

LATU_USE_CUSTOM_SRC ?= "1"

UBOOT_SRC = "${@'git://git@bitbucket.sw.nxp.com/isp/uboot-imx-dcscm.git;protocol=ssh' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'git://github.com/nxp-imx/uboot-imx.git;protocol=https'}"
SRCBRANCH = "${@'lf_v2026.04' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'lf_v2026.04'}"
SRCREV    = "${AUTOREV}"

FILESEXTRAPATHS:prepend:latu-dcsm-imx95 := "${THISDIR}/files/latu-dcsm-imx95:${THISDIR}/files/latu-dcsm-imx95/nor:"

# Select NOR fragment for fspi based on LATU_USE_CUSTOM_SRC:
#   1 (custom latu-dcsm src) -> defconfig-fragment.cfg     (latu-dcsm DTB, CONFIG_OF_UPSTREAM=n)
#   0 (upstream EVK src)     -> defconfig-fragment-src0.cfg (evk-ep-adv7535 DTB, no OF_UPSTREAM override)
LATU_NOR_DEFCONFIG_FRAG = "${@'file://nor/latu-nor-defconfig.cfg' if d.getVar('LATU_USE_CUSTOM_SRC') == '1' else 'file://nor/defconfig-fragment-src0.cfg'}"

# Add both env files and both NOR defconfig fragments to SRC_URI.
# The correct NOR fragment for fspi is selected per LATU_USE_CUSTOM_SRC at build time.
# The SD config always uses nor/defconfig-fragment.cfg and is fixed up in do_configure:append.
SRC_URI:append:latu-dcsm-imx95 = " \
    file://custom-bmc-env.cmd \
    file://custom-bmc-env-nor.cmd \
    ${LATU_NOR_DEFCONFIG_FRAG} \
"

# Use NOR-specific env name — overrides meta-imx95's default "custom-bmc-env"
UBOOT_ENV:latu-dcsm-imx95 = "custom-bmc-env-nor"

# Path to env files resolved at parse time via BBPATH
LATU_SD_ENV_FILE  = "${@bb.utils.which(d.getVar('BBPATH'), 'recipes-bsp/u-boot/files/latu-dcsm-imx95/custom-bmc-env.cmd')}"
LATU_NOR_ENV_FILE = "${@bb.utils.which(d.getVar('BBPATH'), 'recipes-bsp/u-boot/files/latu-dcsm-imx95/nor/custom-bmc-env-nor.cmd')}"

# Ensure uboot-config class is active
inherit uboot-config

# Copy both env files into B and UNPACKDIR so U-Boot make can find them.
do_copy_custom_env:latu-dcsm-imx95() {
    install -d ${B}

    if [ -f "${LATU_SD_ENV_FILE}" ]; then
        install -m 0644 "${LATU_SD_ENV_FILE}" "${B}/custom-bmc-env.cmd"
        install -m 0644 "${LATU_SD_ENV_FILE}" "${UNPACKDIR}/custom-bmc-env.cmd"
    else
        bbfatal "custom-bmc-env.cmd not found at ${LATU_SD_ENV_FILE}"
    fi

    if [ -f "${LATU_NOR_ENV_FILE}" ]; then
        install -m 0644 "${LATU_NOR_ENV_FILE}" "${B}/custom-bmc-env-nor.cmd"
        install -m 0644 "${LATU_NOR_ENV_FILE}" "${UNPACKDIR}/custom-bmc-env-nor.cmd"
    else
        bbfatal "custom-bmc-env-nor.cmd not found at ${LATU_NOR_ENV_FILE}"
    fi
}

# Fix up the SD config after all fragments are merged.
# defconfig-fragment-src0.cfg is applied to SD; this task corrects env storage back to MMC
# and restores the upstream EVK DTB with CONFIG_OF_UPSTREAM=y.
do_configure:append:latu-dcsm-imx95() {
    if [ "${LATU_USE_CUSTOM_SRC}" != "1" ]; then
        return
    fi
    SD_CONFIG="${B}/imx95_19x19_evk_defconfig-sd/.config"
    if [ -f "${SD_CONFIG}" ]; then
        bbnote "latu-dcsm: fixing SD .config for MMC env storage"
        # Switch env storage from SPI flash to MMC
        sed -i 's/^CONFIG_ENV_IS_IN_SPI_FLASH=y/# CONFIG_ENV_IS_IN_SPI_FLASH is not set/' "${SD_CONFIG}"
        sed -i 's/^# CONFIG_ENV_IS_IN_MMC is not set/CONFIG_ENV_IS_IN_MMC=y/' "${SD_CONFIG}"
        # Fix env offset to safe MMC location (7 MB raw gap)
        sed -i 's/^CONFIG_ENV_OFFSET=0x49A0000/CONFIG_ENV_OFFSET=0x700000/' "${SD_CONFIG}"
        # Remove NOR-specific settings
        sed -i '/^CONFIG_ENV_OFFSET_REDUND=/d' "${SD_CONFIG}"
        sed -i 's/^CONFIG_ENV_SECT_SIZE=0x10000/CONFIG_ENV_SECT_SIZE=0x4000/' "${SD_CONFIG}"
        sed -i 's/^CONFIG_ENV_SIZE=0x10000/CONFIG_ENV_SIZE=0x4000/' "${SD_CONFIG}"
        # Switch embedded env text file to SD env
        sed -i 's/CONFIG_ENV_DEFAULT_ENV_TEXT_FILE="custom-bmc-env-nor.cmd"/CONFIG_ENV_DEFAULT_ENV_TEXT_FILE="custom-bmc-env.cmd"/' "${SD_CONFIG}"
        sed -i 's|CONFIG_DEFAULT_DEVICE_TREE=.*|CONFIG_DEFAULT_DEVICE_TREE="freescale/imx95-19x19-evk"|' "${SD_CONFIG}"
        sed -i 's|^CONFIG_DEFAULT_FDT_FILE=.*|CONFIG_DEFAULT_FDT_FILE="imx95-19x19-evk-ep-adv7535.dtb"|' "${SD_CONFIG}"
        sed -i 's/# CONFIG_OF_UPSTREAM is not set/CONFIG_OF_UPSTREAM=y/' "${SD_CONFIG}"
        echo '# CONFIG_OF_UPSTREAM_BUILD_VENDOR is not set' >> "${SD_CONFIG}"
        echo '# CONFIG_OF_UPSTREAM_INCLUDE_LOCAL_FALLBACK_DTBOS is not set' >> "${SD_CONFIG}"
        bbnote "latu-dcsm: SD .config settings after fixup:"
        grep 'ENV_IS_IN\|ENV_OFFSET\|ENV_SIZE\|ENV_DEFAULT_ENV_TEXT\|DEFAULT_FDT_FILE\|DEFAULT_DEVICE_TREE\|OF_UPSTREAM' "${SD_CONFIG}" || true
    fi
}

# Copy env files into each config build subdir before compile.
# U-Boot Makefile resolves CONFIG_ENV_DEFAULT_ENV_TEXT_FILE relative to objtree.
do_compile:prepend:latu-dcsm-imx95() {
    for cfg_dir in ${B}/*/; do
        [ -d "${cfg_dir}" ] || continue
        bbnote "latu-dcsm: staging env files into ${cfg_dir}"
        install -m 0644 "${B}/custom-bmc-env.cmd"    "${cfg_dir}/custom-bmc-env.cmd"
        install -m 0644 "${B}/custom-bmc-env-nor.cmd" "${cfg_dir}/custom-bmc-env-nor.cmd"
    done
}

# Deploy both env cmd files
do_deploy:append:latu-dcsm-imx95() {
    install -d ${DEPLOYDIR}
    [ -f "${B}/custom-bmc-env.cmd" ]     && install -m 0644 ${B}/custom-bmc-env.cmd     ${DEPLOYDIR}/custom-bmc-env.cmd
    [ -f "${B}/custom-bmc-env-nor.cmd" ] && install -m 0644 ${B}/custom-bmc-env-nor.cmd ${DEPLOYDIR}/custom-bmc-env-nor.cmd
}
