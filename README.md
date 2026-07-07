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
cd meta-nxp && git checkout wrynose-temp-clean
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

| Patch | Platform | Description |
|---|---|---|
| `0001-openbmc-imx91-imx93-support` | imx91/93 | OpenBMC DTS + Makefile |
| `0002-P3T2030-temperature-sensor-imx93` | imx91/93 | P3T2030 sensor driver |
| `0003-imx93-usb-peripheral-mode` | imx91/93 | USB peripheral mode |
| `0004-imx943-local-display` | imx943 | DCIF local display |
| `0005-imx943-antmicro-dc-scm-dts` | imx943 | Antmicro board DTS |
| `0006-openbmc-imx95-frdm-support` | imx95 | OpenBMC DTS + Makefile |
| `0010-ikvm-pcie-ep-drivers` | imx943/95 | iKVM PCIe EP drivers |
| `0011-ikvm-drm-dpu95-bridge` | imx943/95 | iKVM DRM/DPU95/bridge |
| `0012-ikvm-dts` | imx943/95 | iKVM DTS/Makefile |
| `0013-drm-imx-dpu95-STRIDE_OVERRIDE` | imx943/95 | DPU95 stride property |
| `0014-V4L2-bridge-driver` | imx943/95 | V4L2 PCIe bridge |
| `0015-drm-bridge-lt9611uxc-EDID` | imx943/95 | lt9611uxc EDID support |

---

## License

This layer is provided under MIT and Apache 2.0 licenses as included with the
source tree.
