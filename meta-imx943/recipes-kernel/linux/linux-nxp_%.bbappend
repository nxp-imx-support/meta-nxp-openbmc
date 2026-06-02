require conf/machine/include/imx943.inc
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://imx_openbmc_defconfig"
SRC_URI += "file://0001-Add-Antmicro-imx943-dc-scm-device-tree-support.patch"
S = "${WORKDIR}/git"

# Copy defconfig into kernel source before metadata check
do_kernel_metadata:prepend() {
    cp ${UNPACKDIR}/imx_openbmc_defconfig ${S}/arch/arm64/configs/
}
