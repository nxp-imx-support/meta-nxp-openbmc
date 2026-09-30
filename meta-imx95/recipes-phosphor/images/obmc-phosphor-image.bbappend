IMAGE_INSTALL:append = " nxp-pci-gop"
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'fpga-sim qspi-mailbox obmf-driver obmf-bmc-apps', '', d)}"
IMAGE_INSTALL:append = " dpu-drm-app"

# NOR flash image type for evb-imx95-evk-nor machine
inherit image_types_nor
IMAGE_FSTYPES:evb-imx95-evk-nor = "jffs2 norflash"
EXTRA_IMAGECMD:jffs2:evb-imx95-evk-nor = "--pad --no-cleanmarkers --eraseblock=0x10000"
IMAGE_INSTALL:append = " usb-hid-forwarder"
