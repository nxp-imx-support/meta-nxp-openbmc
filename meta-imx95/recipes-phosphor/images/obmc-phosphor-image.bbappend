IMAGE_INSTALL:append = " nxp-pci-gop"
# Mailbox stack (public: has a GitHub source) is installed on all builds.
IMAGE_INSTALL:append = " mock-server qspi-mailbox"
# OBMF is internal-only.
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:append = " dpu-drm-app"

# NOR flash image type for evk-imx95-nor machine
inherit image_types_nor
IMAGE_FSTYPES:evk-imx95-nor = "jffs2 norflash"
EXTRA_IMAGECMD:jffs2:evk-imx95-nor = "--pad --no-cleanmarkers --eraseblock=0x10000"
IMAGE_INSTALL:append = " usb-hid-forwarder"
