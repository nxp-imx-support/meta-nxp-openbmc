SUMMARY = "OBMF USB/ICP BMC kernel module (bmc_obmf_driver)"
DESCRIPTION = "Out-of-tree kernel module from the ioe_obmf_linux project: \
obmf_icp_usb_bmc (OBMF ICP-over-USB BMC driver). Loaded on demand, not at boot."

# The kernel module is GPL-2.0-only, not Apache-2.0 like the rest of the
# ioe_obmf_linux project: obmf_icp_usb_bmc.c declares MODULE_LICENSE("GPL") and
# links against kernel interfaces exported GPL-only (i3c_master_register,
# i3c_master_do_daa, i3c_master_add_i3c_dev_locked, devm_gpiochip_add_data),
# which a GPL-incompatible module cannot resolve. The upstream sources carry
# SPDX-License-Identifier: GPL-2.0-only and ship the terms in
# LICENSES/GPL-2.0-only.txt; the repo-root LICENSE is the Apache-2.0 text that
# covers the userspace parts (see bmc-apps_git.bb), so it is not the right file
# to check here.
LICENSE = "GPL-2.0-only"

inherit module

# Top of tree of the main branch.
#SRC_URI = "git://git@bitbucket.sw.nxp.com/~nxa15309/ioe_obmf_linux.git;protocol=ssh;branch=main"
SRC_URI = "git://git@bitbucket.sw.nxp.com/sbs/ioe_obmf_linux.git;protocol=ssh;branch=main"
#SRCREV = "${AUTOREV}"
SRCREV = "83d2428d36e27347c4cfd99d64edc611a17e9d3e"
PV = "1.0+git${SRCPV}"

# The module lives in the bmc_obmf_driver kbuild subdirectory of the repo.
# Point S there so module.bbclass drives kbuild modules/modules_install
# (M=${S}) directly. The license file is at the repo root, one level up.
#
# The git fetcher clones the repo to ${UNPACKDIR}/${BP}, not the legacy
# ${UNPACKDIR}/git stub, so descend from ${BP} to reach the module Makefile.
S = "${UNPACKDIR}/${BP}/bmc_obmf_driver"
LIC_FILES_CHKSUM = "file://${UNPACKDIR}/${BP}/LICENSES/GPL-2.0-only.txt;md5=cddb1ca8562c38d09e789a0725fe5d7f"


# The module is loaded on demand (modprobe obmf_icp_usb_bmc),
# not at boot. Do not set KERNEL_MODULE_AUTOLOAD.

RPROVIDES:${PN} += "kernel-module-obmf-icp-usb-bmc"
