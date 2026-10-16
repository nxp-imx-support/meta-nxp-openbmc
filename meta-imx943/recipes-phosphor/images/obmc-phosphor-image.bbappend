IMAGE_INSTALL:append = " nxp-pci-gop"
# Mailbox stack (public: has a GitHub source) is installed on all builds.
IMAGE_INSTALL:append = " mock-server qspi-mailbox"
# OBMF is internal-only.
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'obmf-driver obmf-bmc-apps', '', d)}"
# Do not install OBMF on evk-imx943-am.
IMAGE_INSTALL:remove:evk-imx943-am = "obmf-driver obmf-bmc-apps"
IMAGE_INSTALL:append = " dpu-drm-app"
IMAGE_INSTALL:append = " usb-hid-forwarder"
