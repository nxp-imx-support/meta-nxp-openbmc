require conf/machine/include/imx943.inc
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://imx_openbmc_defconfig"
SRC_URI += "file://0001-Local-display-for-i.MX943.patch"
SRC_URI += "file://0001-Add-Antmicro-imx943-dc-scm-device-tree-support.patch"
S = "${WORKDIR}/git"

SRC_URI += "file://disable-console_fb.cfg"
KERNEL_CONFIG_FRAGMENTS += "disable-console_fb.cfg"

# Copy defconfig into kernel source before metadata check
do_kernel_metadata:prepend() {
    cp ${UNPACKDIR}/imx_openbmc_defconfig ${S}/arch/arm64/configs/
}

KERNEL_DEVICETREE:append = " freescale/imx943-evk.dtb"
KERNEL_DEVICETREE:append = " freescale/imx943-evk-pcie1-ep.dtb"
