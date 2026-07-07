# Copyright 2017-2026 NXP
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

IMX_M4_DEMOS      = ""

IMX_M4_DEMOS:mx91-nxp-bsp = ""
IMX_M4_DEMOS:mx93-nxp-bsp = ""
IMX_M4_DEMOS:mx943-nxp-bsp = "imx-mcore-demos:do_deploy"

M4_DEFAULT_IMAGE ?= "m4_image.bin"
M4_DEFAULT_IMAGE:mx91-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx93-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx943-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx95-nxp-bsp = "${M4_DEFAULT_IMAGE_MX95}"

do_compile[depends] += "${IMX_M4_DEMOS}"

do_compile:prepend() {
    case ${SOC_FAMILY} in
    mx943)
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/${M33_IMAGE} ${BOOT_STAGING}/m33s_image.bin
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/${M70_IMAGE} ${BOOT_STAGING}/m70_image.bin
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/${M71_IMAGE} ${BOOT_STAGING}/m71_image.bin
    ;;
    mx95)
         # Only copy if mcore-demos directory exists
        if [ -d ${DEPLOY_DIR_IMAGE}/mcore-demos ]; then
            cp  ${DEPLOY_DIR_IMAGE}/mcore-demos/${M4_DEFAULT_IMAGE} ${BOOT_STAGING}/m7_image.bin
        else
            bbnote "mcore-demos not found, skipping M7 image copy for mx95"
        fi
        ;;
    esac
}

do_deploy:append() {
    case ${SOC_FAMILY} in
    mx943)
        install -m 0644 ${DEPLOY_DIR_IMAGE}/mcore-demos/${M33_IMAGE}                ${DEPLOYDIR}/${BOOT_TOOLS}
        install -m 0644 ${DEPLOY_DIR_IMAGE}/mcore-demos/${M70_IMAGE}                ${DEPLOYDIR}/${BOOT_TOOLS}
        install -m 0644 ${DEPLOY_DIR_IMAGE}/mcore-demos/${M71_IMAGE}                ${DEPLOYDIR}/${BOOT_TOOLS}
        ;;
    mx95)
         if [ -d ${DEPLOY_DIR_IMAGE}/mcore-demos ]; then
            install -m 0644 ${DEPLOY_DIR_IMAGE}/mcore-demos/${M4_DEFAULT_IMAGE} ${DEPLOYDIR}/${BOOT_TOOLS}
        fi
        ;;
    esac
}

# Ensure flash.bin is staged where do_deploy (or inherited classes) expect it
do_install:append() {
    install -d ${WORKDIR}/deploy-imx-boot
    FLASH=$(find ${S} -maxdepth 3 -name flash.bin | head -n 1)

    [ -z "$FLASH" ] && bbfatal "flash.bin not found for ${SOC_FAMILY}"
    install -m 0644 "$FLASH" ${WORKDIR}/deploy-imx-boot/flash.bin

    # (Optional safety) Also ensure BOOT_STAGING has flash.bin if missing
    if [ ! -f ${BOOT_STAGING}/flash.bin ]; then
        install -d ${BOOT_STAGING}
        install -m 0644 ${WORKDIR}/deploy-imx-boot/flash.bin ${BOOT_STAGING}/flash.bin
    fi
}

# Ensure flash.bin is staged before any deploy hooks run
do_deploy:prepend() {
    # Create the staging directory that deploy hooks expect
    install -d ${WORKDIR}/deploy-imx-boot
    FLASH=$(find ${S} -maxdepth 3 -name flash.bin | head -n 1)

    [ -z "$FLASH" ] && bbfatal "flash.bin not found for ${SOC_FAMILY}"
    install -m 0644 "$FLASH" ${WORKDIR}/deploy-imx-boot/flash.bin

    install -d ${DEPLOYDIR}
    install -m 0644 ${WORKDIR}/deploy-imx-boot/flash.bin ${DEPLOYDIR}/imx-boot-${MACHINE}.bin

    # Optional: also keep BOOT_STAGING in sync (used by deploy_* helpers)
    if [ ! -f ${BOOT_STAGING}/flash.bin ]; then
        install -d ${BOOT_STAGING}
        install -m 0644 ${WORKDIR}/deploy-imx-boot/flash.bin ${BOOT_STAGING}/flash.bin
    fi
}
