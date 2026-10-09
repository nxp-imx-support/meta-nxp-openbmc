IMAGE_INSTALL:append = " bmc-init"

IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'mock-server qspi-mailbox obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:remove = " packagegroup-fsl-optee-imx "

OBMC_WEBUI = "webui-vue"
OBMC_IMAGE_EXTRA_INSTALL:append:nxp = " webui-vue phosphor-image-signing"
