IMAGE_INSTALL:append = " bmc-init"
IMAGE_INSTALL:remove = " packagegroup-fsl-optee-imx "
IMAGE_INSTALL:append = " nxp-pci-gop"
IMAGE_INSTALL:append = " dpu-drm-app"

OBMC_WEBUI = "webui-vue"
OBMC_IMAGE_EXTRA_INSTALL:append:nxp = " webui-vue phosphor-image-signing"
