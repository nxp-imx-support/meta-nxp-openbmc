# No platform-specific cfg - all config in openbmc_common.cfg
# KERNEL_DEVICETREE is set in meta-evb-imx93/conf/machine/evb-imx93.conf

# -----------------------------------------------------------------
# NOR flash kernel additions for evb-imx93-nor machine
# -----------------------------------------------------------------
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Apply the FlexSPI host driver kernel config fragment
SRC_URI:append:evb-imx93-nor = " file://nor-flexspi.cfg"
