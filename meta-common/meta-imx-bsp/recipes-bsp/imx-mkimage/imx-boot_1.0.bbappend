# Copyright 2017-2026 NXP
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

IMX_M4_DEMOS      = ""
IMX_M4_DEMOS:mx8-nxp-bsp  = "imx-m4-demos:do_deploy"
IMX_M4_DEMOS:mx8m-nxp-bsp = ""
IMX_M4_DEMOS:mx8ulp-nxp-bsp = "imx-m33-demos:do_deploy"
IMX_M4_DEMOS:mx91-nxp-bsp = ""
IMX_M4_DEMOS:mx93-nxp-bsp = ""
IMX_M4_DEMOS:mx943-nxp-bsp = "imx-mcore-demos:do_deploy"
IMX_M4_DEMOS:mx95-nxp-bsp = "imx-m7-demos:do_deploy"

M4_DEFAULT_IMAGE ?= "m4_image.bin"
M4_DEFAULT_IMAGE:mx8qxp-nxp-bsp = "imx8qx_m4_TCM_power_mode_switch.bin"
M4_DEFAULT_IMAGE:mx8dxl-nxp-bsp = "imx8dxl_m4_TCM_power_mode_switch.bin"
M4_DEFAULT_IMAGE:mx8dx-nxp-bsp = "imx8qx_m4_TCM_power_mode_switch.bin"
M4_DEFAULT_IMAGE:mx8ulp-nxp-bsp = "imx8ulp_m33_TCM_power_mode_switch.bin"
M4_DEFAULT_IMAGE:mx91-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx93-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx943-nxp-bsp = ""
M4_DEFAULT_IMAGE:mx95-nxp-bsp = "${M4_DEFAULT_IMAGE_MX95}"

do_compile[depends] += "${IMX_M4_DEMOS}"

do_compile:prepend() {
    case ${SOC_FAMILY} in
    mx8)
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/imx8qm_m4_TCM_power_mode_switch_m40.bin \
                                                             ${BOOT_STAGING}/m4_image.bin
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/imx8qm_m4_TCM_power_mode_switch_m41.bin \
                                                             ${BOOT_STAGING}/m4_1_image.bin
        ;;
    mx8x)
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/${M4_DEFAULT_IMAGE}           ${BOOT_STAGING}/m4_image.bin
        ;;
    mx8ulp)
        cp ${DEPLOY_DIR_IMAGE}/mcore-demos/${M4_DEFAULT_IMAGE}       ${BOOT_STAGING}/m33_image.bin
        ;;
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
    mx8)
        install -m 0644 ${BOOT_STAGING}/m4_image.bin         ${DEPLOYDIR}/${BOOT_TOOLS}
        install -m 0644 ${BOOT_STAGING}/m4_1_image.bin       ${DEPLOYDIR}/${BOOT_TOOLS}
        ;;
    mx8x)
        install -m 0644 ${BOOT_STAGING}/m4_image.bin         ${DEPLOYDIR}/${BOOT_TOOLS}
        ;;
    mx8ulp)
        install -m 0644 ${BOOT_STAGING}/m33_image.bin        ${DEPLOYDIR}/${BOOT_TOOLS}
        ;;
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
    # Staging directory used by some deploy hooks
    install -d ${WORKDIR}/deploy-imx-boot

    # Find the built flash.bin from common locations and stage it
    if [ -f ${S}/iMX93/flash.bin ]; then
        install -m 0644 ${S}/iMX93/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${B}/iMX93/flash.bin ]; then
        install -m 0644 ${B}/iMX93/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${S}/flash.bin ]; then
        install -m 0644 ${S}/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${B}/flash.bin ]; then
        install -m 0644 ${B}/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    else
        bbfatal "imx-boot: flash.bin not found under expected locations"
    fi

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

    # Put the built flash.bin where the hook expects it
    if [ -f ${S}/iMX93/flash.bin ]; then
        install -m 0644 ${S}/iMX93/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${B}/iMX93/flash.bin ]; then
        install -m 0644 ${B}/iMX93/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${S}/flash.bin ]; then
        install -m 0644 ${S}/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    elif [ -f ${B}/flash.bin ]; then
        install -m 0644 ${B}/flash.bin ${WORKDIR}/deploy-imx-boot/flash.bin
    else
        bbfatal "imx-boot: flash.bin not found under expected locations (S/B; with/without iMX93/)."
    fi

    # Optional: also keep BOOT_STAGING in sync (used by deploy_* helpers)
    if [ ! -f ${BOOT_STAGING}/flash.bin ]; then
        install -d ${BOOT_STAGING}
        install -m 0644 ${WORKDIR}/deploy-imx-boot/flash.bin ${BOOT_STAGING}/flash.bin
    fi
}
