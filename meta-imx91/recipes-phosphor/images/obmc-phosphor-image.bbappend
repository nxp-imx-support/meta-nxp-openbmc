IMAGE_INSTALL:append = " bmc-init"

# Mailbox stack (public: has a GitHub source) is installed on all builds.
IMAGE_INSTALL:append = " mock-server qspi-mailbox"
# OBMF is internal-only.
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:remove = " packagegroup-fsl-optee-imx "

OBMC_WEBUI = "webui-vue"
OBMC_IMAGE_EXTRA_INSTALL:append:nxp = " webui-vue phosphor-image-signing"
