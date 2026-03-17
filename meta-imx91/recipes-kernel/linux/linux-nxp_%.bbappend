require conf/machine/include/imx91.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://imx_openbmc_defconfig"
SRC_URI += "file://0001-openbmc-add-support-for-imx93-evk-frdm-imx91-evk.patch"
SRC_URI += "file://0002-P3T2030-temperature-sensor-support-for-IMX.93.patch"

S = "${WORKDIR}/git"

# Copy defconfig into kernel source before metadata check
do_kernel_metadata:prepend() {
    cp ${UNPACKDIR}/imx_openbmc_defconfig ${S}/arch/arm64/configs/
}

# i.MX91 uses Image, never zImage
KBUILD_IMAGE = "Image"

# ARM64 kernel: disable zImage, force Image
KERNEL_IMAGETYPE:evb-imx91 = "Image"
KERNEL_IMAGETYPES:evb-imx91 = "Image fitImage"
KBUILD_IMAGE = "Image"

# Remove zImage from types used by kernel.bbclass
KERNEL_IMAGETYPE_FOR_MAKE:evb-imx91 = "Image"

# Override build target to avoid zImage
do_compile:append() {
    unset zImage
}
