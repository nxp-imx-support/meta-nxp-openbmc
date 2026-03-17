do_compile[depends] += "firmware-ele-imx:do_deploy"
do_compile[depends] += "imx-boot-firmware-files:do_deploy"

do_compile:prepend() {
    if [ -n "${SECO_FIRMWARE_NAME}" ]; then
        if [ ! -e "${DEPLOY_DIR_IMAGE}/${SECO_FIRMWARE_NAME}" ] &&
           [ -e "${RECIPE_SYSROOT}/lib/firmware/imx/ele/${SECO_FIRMWARE_NAME}" ]; then
            install -d ${DEPLOY_DIR_IMAGE}
            install -m 0644 "${RECIPE_SYSROOT}/lib/firmware/imx/ele/${SECO_FIRMWARE_NAME}" "${DEPLOY_DIR_IMAGE}/"
        fi
    fi
}
