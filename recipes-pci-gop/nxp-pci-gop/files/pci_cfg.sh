#!/bin/sh

# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

CONF_FILE=/etc/kvm.conf
EP_CONFIGFS=/sys/kernel/config/pci_ep
FUNC_DIR=${EP_CONFIGFS}/functions/pci_epf_imx9_vga/func3
CTRL_DIR=${EP_CONFIGFS}/controllers/4c380000.pcie-ep
MODULE_PARAMS=/sys/module/pci_epf_imx9_vga/parameters
PARAMS_SET_FLAG=/run/pci_epf_imx9_vga_params_set

# ------------------------------------------------------------------ #
# Set module parameters once per boot                                #
# ------------------------------------------------------------------ #

if [ ! -f "$PARAMS_SET_FLAG" ]; then

	KVM_MODE="pcie_video_usb_hid"
	DISPLAY_RESOLUTION="1080p"

	if [ -f "$CONF_FILE" ]; then
		. "$CONF_FILE"
		[ -n "$kvm_mode" ]           && KVM_MODE="$kvm_mode"
		[ -n "$display_resolution" ] && DISPLAY_RESOLUTION="$display_resolution"
	else
		echo "Warning: $CONF_FILE not found, using defaults"
	fi

	if [ -d "$MODULE_PARAMS" ]; then
		echo "$KVM_MODE"           > ${MODULE_PARAMS}/kvm_mode
		echo "$DISPLAY_RESOLUTION" > ${MODULE_PARAMS}/display_resolution
		echo "Module params set:"
		echo "  kvm_mode           = $(cat ${MODULE_PARAMS}/kvm_mode)"
		echo "  display_resolution = $(cat ${MODULE_PARAMS}/display_resolution)"
		# Mark as done — subsequent watch iterations skip this block
		touch "$PARAMS_SET_FLAG"
	else
		echo "Warning: $MODULE_PARAMS not found — module not loaded yet"
	fi

fi

# ------------------------------------------------------------------ #
# Configure PCIe EP function via configfs                            #
# ------------------------------------------------------------------ #

cd "$EP_CONFIGFS" || { echo "Error: configfs not mounted at $EP_CONFIGFS"; exit 1; }

if [ ! -d "$FUNC_DIR" ]; then
	mkdir -p functions/pci_epf_imx9_vga/func3 || {
		echo "Error: failed to create function directory"
		exit 1
	}
fi

echo 0x1131 > functions/pci_epf_imx9_vga/func3/vendorid
echo 0x1234 > functions/pci_epf_imx9_vga/func3/deviceid

echo "vendorid = $(cat functions/pci_epf_imx9_vga/func3/vendorid)"
echo "deviceid = $(cat functions/pci_epf_imx9_vga/func3/deviceid)"

echo 16 > functions/pci_epf_imx9_vga/func3/msi_interrupts
echo 8  > functions/pci_epf_imx9_vga/func3/msix_interrupts

if [ ! -L "${CTRL_DIR}/func3" ]; then
	ln -s functions/pci_epf_imx9_vga/func3/ controllers/4c380000.pcie-ep/ || {
		echo "Error: failed to link function to controller"
		exit 1
	}
	echo "Function linked to controller"
fi

#echo 1 > ${CTRL_DIR}/start

echo "setup_pcie_ep.sh completed"
exit 0

