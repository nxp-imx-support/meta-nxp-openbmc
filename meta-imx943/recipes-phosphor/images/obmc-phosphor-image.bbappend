IMAGE_INSTALL:append = " nxp-pci-gop"
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'mock-server qspi-mailbox obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:append = " dpu-drm-app"
IMAGE_INSTALL:append = " usb-hid-forwarder"
