NXP i.MX9x OpenBMC BSP Layer (`meta-nxp`)
=========
This is the NXP i.MX9x Board Support Package (BSP) Yocto layer for enabling
OpenBMC on NXP i.MX 9X series SoCs, including i.MX91, i.MX93, i.MX943 & i.MX95.
These SoCs are ARM-based platforms with external DDR and support
a large set of peripherals of NXP.

More information about the NXP IMX 9 Application Processors can be found at:
[here](https://www.nxp.com/products/processors-and-microcontrollers/arm-processors/i-mx-applications-processors/i-mx-9-processors:IMX9-PROCESSORS).

---

## 1. Layer Dependencies

This layer is applicable for OpenBMC github project:

- `https://github.com/openbmc/openbmc`
- OpenBMC release: `wrynose`

This layer depends on the following OpenBMC/Yocto layers:

- `meta`
- `meta-phosphor`
- `meta-openembedded` (meta-oe, meta-networking, meta-python)
- `meta-arm` / `meta-arm-toolchain`

This repository includes NXP-specific sublayers:

- `meta-common` (shared BSP content: meta-imx-bsp)
- `meta-evb-imx91` (machine config for i.MX91 FRDM board)
- `meta-evb-imx93` (machine config for i.MX93 FRDM board)
- `meta-evb-imx943` (machine config for i.MX943 EVK board)
- `meta-evb-imx943-am` (machine config for i.MX943 Antmicro DC-SCM board)
- `meta-evb-imx95` (machine config for i.MX95 15x15 FRDM board)
- `meta-evb-imx95-evk` (machine config for i.MX95 19x19 EVK board)
- `meta-imx91` (SoC-specific recipes for i.MX91)
- `meta-imx93` (SoC-specific recipes for i.MX93)
- `meta-imx943` (SoC-specific recipes for i.MX943)
- `meta-imx95` (SoC-specific recipes for i.MX95)

---

## 2. NXP Kernel / Dependent Trees

The BSP integrates the NXP Linux kernel:

```
- NXP Kernel Tree:
  URI:    https://github.com/nxp-imx/linux-imx
  branch: lf-6.18.y
  tag:    lf-6.18.2-1.0.0
  commit: 07bb2ca4e8a7b292490c183a02dc8bff6645aab7
```

Additional dependent components:

```
- NXP U-Boot:
  URI:    https://github.com/nxp-imx/uboot-imx
  branch: lf_v2025.04
  tag:    lf-6.18.2_1.0.0

- NXP ARM Trusted Firmware (ATF):
  URI:    https://github.com/nxp-imx/imx-atf
  branch: lf_v2.12
  tag:    lf-6.18.2_1.0.0

- NXP System Manager (SM):
  URI:    https://github.com/nxp-imx/imx-sm
  branch: master
  tag:    lf-6.18.2_1.0.0

- NXP OEI:
  URI:    https://github.com/nxp-imx/imx-oei
  branch: master
  tag:    lf-6.18.2_1.0.0

- NXP mkimage:
  URI:    https://github.com/nxp-imx/imx-mkimage
  branch: lf-6.18.2_1.0.0
  tag:    lf-6.18.2_1.0.0
```

---

## 3. Supported Machines

| Machine | SoC | Board |
|---|---|---|
| `evb-imx91` | i.MX91 | 11x11 FRDM |
| `evb-imx93` | i.MX93 | 11x11 FRDM |
| `evb-imx943` | i.MX943 | 15x15 EVK |
| `evb-imx943-am` | i.MX943 | Antmicro DC-SCM |
| `evb-imx95` | i.MX95 | 15x15 FRDM |
| `evb-imx95-evk` | i.MX95 | 19x19 EVK |

Machine definitions are under:
```
meta-nxp/meta-evb-imx91/conf/machine/
meta-nxp/meta-evb-imx93/conf/machine/
meta-nxp/meta-evb-imx943/conf/machine/
meta-nxp/meta-evb-imx943-am/conf/machine/
meta-nxp/meta-evb-imx95/conf/machine/
meta-nxp/meta-evb-imx95-evk/conf/machine/
```

---

## 4. Basic Build Instructions

Get the Yocto Source Code:
```bash
git clone https://github.com/openbmc/openbmc.git
cd openbmc
git checkout -b wrynose origin/wrynose
git clone https://bitbucket.sw.nxp.com/scm/isp/meta-nxp-openbmc.git meta-nxp
cd meta-nxp && git checkout wrynose
```

Set up build environment for selected machine:
```bash
. setup evb-imx93
# or: evb-imx91 / evb-imx943 / evb-imx943-am / evb-imx95 / evb-imx95-evk
```

Build the image:
```bash
bitbake obmc-phosphor-image
```

Build individual packages:
```bash
bitbake -c cleansstate <package>
bitbake <package>
```

> **Note:** The WIC image will be available at `tmp/deploy/images/<machine>/`

---

## 5. Supported OpenBMC Features

| Feature | Status | Notes |
|---|---|---|
| Remote Console (UART-based) | ✅ | Via `uart-render-controller` |
| Firmware Information | ✅ | `phosphor-software-manager` |
| Thermal Sensor Monitoring | ✅ | `dbus-sensors` + `entity-manager` |
| Host CPU Health | ✅ | `phosphor-state-manager` + `nxp-hostctrl` |
| System Event Log (SEL) | ✅ | `phosphor-sel-logger` |
| LED Control | ✅ | `phosphor-led-manager` |
| Telemetry | ✅ | `dbus-sensors` + Redfish |
| Network Interface Control | ✅ | `phosphor-network` (IPv4/IPv6/DHCP) |
| Security (SSH/SSL/Users) | ✅ | `phosphor-user-manager` + `webui-vue` |
| BMC Firmware Update | ✅ | `phosphor-software-manager` |
| Firmware Inventory | ✅ | `phosphor-software-manager` |
| Firmware Rollback | ✅ | `phosphor-software-manager` |
| iKVM (PCIe EP display) | ✅ | i.MX943 / i.MX95 only |
| Virtual Media (USB NBD) | ✅ | `usb-nbd` |
| MCTP | ✅ | AF-MCTP socket transport |
| PLDM | ✅ | Primary management protocol |

---

## 6. Directory Structure

```
meta-common/           Shared BSP code (meta-imx-bsp)
meta-evb-imx91/        Machine config: i.MX91 FRDM
meta-evb-imx93/        Machine config: i.MX93 FRDM
meta-evb-imx943/       Machine config: i.MX943 EVK
meta-evb-imx943-am/    Machine config: i.MX943 Antmicro DC-SCM
meta-evb-imx95/        Machine config: i.MX95 15x15 FRDM
meta-evb-imx95-evk/    Machine config: i.MX95 19x19 EVK
meta-imx91/            SoC-specific recipes: i.MX91
meta-imx93/            SoC-specific recipes: i.MX93
meta-imx943/           SoC-specific recipes: i.MX943
meta-imx95/            SoC-specific recipes: i.MX95

recipes-bsp/           Bootloader, ATF, low-level BSP
recipes-core/          Core OS modifications (udev, etc.)
recipes-devtools/      Developer tools (nodejs, boost)
recipes-kernel/        Kernel recipe + patches (all platforms)
recipes-phosphor/      OpenBMC phosphor services
```

### Kernel Patches (`recipes-kernel/linux/files/`)

Patches are applied per-machine via `SRC_URI` overrides in
`recipes-kernel/linux/linux-nxp_git.bb`. The "Applied to" column reflects
those overrides (`evb-imx*` machines and the `mx943-nxp-bsp` / `mx95-nxp-bsp`
BSP overrides used for the iKVM PCIe EP group).

| Patch | Applied to | Description |
|---|---|---|
| `0004-ikvm-pcie-ep-local-display-remote-kvm-imx95-6.18` | imx943/95 | iKVM PCIe EP local display + remote KVM base support |
| `0005-openbmc-imx91-imx93-support` | imx91/93 | OpenBMC DTS + Makefile |
| `0006-P3T2030-temperature-sensor-imx93` | imx91/93 | P3T2030 temperature sensor driver |
| `0007-imx93-usb-peripheral-mode` | imx91/93 | USB peripheral mode |
| `0008-imx943-local-display` | imx943 | DCIF local display |
| `0009-imx943-antmicro-dc-scm-dts` | imx943 | Antmicro DC-SCM board DTS |
| `0010-openbmc-imx95-frdm-support` | imx95 | OpenBMC DTS + Makefile |
| `0011-media-ox05b1s-fix-variable-declaration-after-label` | all | ox05b1s build fix (decl after case label) |
| `0012-media-stream2v4l2-fix-vb2-release-and-resolution-upd` | imx943/95 | stream2v4l2 vb2 release + resolution update fix |
| `0013-media-stream2v4l2-use-DPU95-blit-engine-for-zero-cop` | imx943/95 | stream2v4l2 DPU95 blit-engine zero-copy capture |
| `0014-meta-nxp-media-stream2v4l2-add-i.MX94-support-and-fi` | imx943/95 | stream2v4l2 i.MX94 support + 4K display fix |
| `0015-PCI-endpoint-add-alloc_bar-free_bar-ops-to-pci_epf_o` | imx943/95 | Add alloc_bar/free_bar ops to pci_epf_ops |
| `0016-PCI-endpoint-core-restore-generic-BAR-alloc-remove-V` | imx943/95 | Restore generic BAR alloc, remove VGA-specific hacks |
| `0017-PCI-endpoint-add-pci-epf-imx9-vga-driver-for-i.MX9-i` | imx943/95 | New standalone pci-epf-imx9-vga driver for iKVM |
| `0018-PCI-endpoint-Kconfig-Makefile-add-PCI_EPF_IMX9_VGA-e` | imx943/95 | Kconfig/Makefile entry for PCI_EPF_IMX9_VGA |

> **Note:** The `0004` and `0012`–`0018` patches form the iKVM PCIe EP display
> group, applied only on the `mx943-nxp-bsp` and `mx95-nxp-bsp` BSP overrides.
> Kernel config deltas are supplied via `openbmc_common.cfg` (all platforms)
> and `openbmc_imx943_imx95.cfg` (i.MX943/i.MX95 only) rather than patches.

---

## License

This layer is provided under MIT and Apache 2.0 licenses as included with the
source tree.
