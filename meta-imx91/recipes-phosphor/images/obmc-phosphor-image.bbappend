IMAGE_INSTALL:append = " bmc-init"
IMAGE_INSTALL:append = " fpga-sel-bridge fpga-pldm-mctp"
# The FPGA mailbox simulator (fpga-sim) and the QSPI mailbox
# kernel modules (qspi-mailbox) and their userspace validation
# tools depend on UAPI headers and driver hooks that only exist in
# the internal NXP kernel tree. Install them only when building against the
# internal kernel (BMC_LINUX_USE_INTERNAL=1, the default); omit them for the
# public GitHub kernel build.
IMAGE_INSTALL:append = " ${@bb.utils.contains('BMC_LINUX_USE_INTERNAL', '1', 'fpga-sim qspi-mailbox', '', d)}"
IMAGE_INSTALL:remove = " packagegroup-fsl-optee-imx "

OBMC_WEBUI = "webui-vue"
OBMC_IMAGE_EXTRA_INSTALL:append:nxp = " webui-vue phosphor-image-signing"
