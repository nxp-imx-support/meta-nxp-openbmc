# Allow U-Boot to search this layer’s files directory
COMPATIBLE_MACHINE:append = "|evb-imx91"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
