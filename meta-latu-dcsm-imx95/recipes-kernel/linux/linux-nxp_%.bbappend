# Override kernel source repository and branch for latu-dcsm-imx95
# KERNEL_DEVICETREE is set in meta-latu-dcsm-imx95/conf/machine/latu-dcsm-imx95.conf

# latu-dcsm uses a dedicated linux-imx fork with board-specific DTS and drivers.
# The branch lf-6.18.y_latu_dcsm contains all board-specific changes; no extra
# patches or config fragments from the shared meta-nxp recipes are applied.
LATU_DCSM_LINUX_SRC = "git://git@bitbucket.sw.nxp.com/isp/linux-imx.git;protocol=ssh"
LATU_DCSM_LINUX_BRANCH = "lf-6.18.y_latu_dcsm"

# TODO: update SRCREV to the desired commit SHA on branch lf-6.18.y_latu_dcsm
LATU_DCSM_LINUX_SRCREV = "${AUTOREV}"

KERNEL_SRC:latu-dcsm-imx95     = "${LATU_DCSM_LINUX_SRC};branch=${LATU_DCSM_LINUX_BRANCH}"
SRCBRANCH:latu-dcsm-imx95      = "${LATU_DCSM_LINUX_BRANCH}"
SRCREV_machine:latu-dcsm-imx95 = "${LATU_DCSM_LINUX_SRCREV}"
SRCREV:latu-dcsm-imx95         = "${LATU_DCSM_LINUX_SRCREV}"

KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-mipi-4K-lt9611uxc.dtb"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../../recipes-kernel/linux/files:"

# The mx95-nxp-bsp MACHINEOVERRIDES entry would pull in iKVM PCIe EP patches
# from linux-nxp_git.bb via SRC_URI:append:mx95-nxp-bsp. Remove them here
# because the latu-dcsm branch already includes all required changes.
SRC_URI:remove:latu-dcsm-imx95 = " \
    file://0001-arm64-dts-imx95-19x19-latu-dcsm-add-NOR-flash-partit.patch \
    file://0002-arm64-dts-imx95-19x19-evk-add-NOR-flash-partitions-f.patch \
    file://0001-Update-imx95-19x19-latu-dcsm-nor-flash-partitions-si.patch \
    file://0001-Update-imx95-19x19-evk-nor-flash-partitions-size.patch \
    file://0004-ikvm-pcie-ep-local-display-remote-kvm-imx95-6.18.patch \
    file://0012-media-stream2v4l2-fix-vb2-release-and-resolution-upd.patch \
    file://0013-media-stream2v4l2-use-DPU95-blit-engine-for-zero-cop.patch \
    file://0014-meta-nxp-media-stream2v4l2-add-i.MX94-support-and-fi.patch \
    file://0015-PCI-endpoint-add-alloc_bar-free_bar-ops-to-pci_epf_o.patch \
    file://0016-PCI-endpoint-core-restore-generic-BAR-alloc-remove-V.patch \
    file://0017-PCI-endpoint-add-pci-epf-imx9-vga-driver-for-i.MX9-i.patch \
    file://0018-PCI-endpoint-Kconfig-Makefile-add-PCI_EPF_IMX9_VGA-e.patch \
    file://0019-PCI-endpoint-Add-iKVM-HID-input-support-to-i.MX9-VGA.patch \
    file://0020-PCI-endpoint-Add-configurable-iKVM-display-and-KVM-m.patch \
    file://0021-arm64-dts-imx95-Add-no-display-DPU-overlay-for-PCIe-.patch \
"

SRC_URI:append:latu-dcsm-imx95 = " \
    file://openbmc_common.cfg \
    file://openbmc_imx943_imx95.cfg \
    file://latu-dcsm.cfg \
"
