# KERNEL_DEVICETREE is set in meta-latu-dcsm-imx95/conf/machine/latu-dcsm-imx95.conf

# conf/machine/include/nxp.inc (BMC_LINUX_SRC/_BRANCH/_SRCREV), which selects
# the internal Bitbucket mirror or the public GitHub tree from the single
# BMC_LINUX_USE_INTERNAL switch. No kernel patches are applied; this recipe
# only adds config fragments.

KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-adv7535.dtb"
KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/${DTB_BASENAME_ORIG}-ep-mipi-4K-lt9611uxc.dtb"
KERNEL_DEVICETREE:append:latu-dcsm-imx95 = " freescale/imx95-dcsm-mailbox.dtbo"

DEPENDS:append:latu-dcsm-imx95 = " dtc-native"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../../recipes-kernel/linux/files:"

# Board config fragments on top of the shared OpenBMC ones.
SRC_URI:append:latu-dcsm-imx95 = " \
    file://openbmc_common.cfg \
    file://openbmc_imx943_imx95.cfg \
    file://latu-dcsm.cfg \
"

# After kernel deploy, use fdtoverlay to produce merged DTBs for NOR slots.
# imx95-dcsm-mailbox.dtbo is the standalone overlay built by the kernel.
# Merge it into the latu-dcsm and EVK DTBs used in NOR slots 1-3.
do_deploy:append:latu-dcsm-imx95() {
    local dtbo="${DEPLOYDIR}/imx95-dcsm-mailbox.dtbo"
    if [ ! -f "${dtbo}" ]; then
        bbwarn "imx95-dcsm-mailbox.dtbo not found - skipping fdtoverlay merge"
        return
    fi

    # fdtoverlay lives in the native sysroot - find it explicitly
    local fdtoverlay_bin="${RECIPE_SYSROOT_NATIVE}/usr/bin/fdtoverlay"
    if [ ! -x "${fdtoverlay_bin}" ]; then
        bbwarn "fdtoverlay not found at ${fdtoverlay_bin} - skipping merge"
        return
    fi

    for base in \
        "imx95-19x19-latu-dcsm.dtb" \
        "imx95-19x19-evk-ep-adv7535.dtb" \
        "imx95-19x19-evk-ep-mipi-4K-lt9611uxc.dtb"; do
        local src="${DEPLOYDIR}/${base}"
        if [ ! -f "${src}" ]; then
            bbwarn "fdtoverlay: ${base} not found - skipping"
            continue
        fi
        bbnote "fdtoverlay: merging ${base} + imx95-dcsm-mailbox.dtbo"
        ${fdtoverlay_bin} -i "${src}" -o "${src}.tmp" "${dtbo}" && mv "${src}.tmp" "${src}"
    done
}
