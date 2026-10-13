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
- `meta-frdm-imx91` (machine config for i.MX91 FRDM board)
- `meta-frdm-imx93` (machine config for i.MX93 FRDM board)
- `meta-evb-imx943` (machine config for i.MX943 EVK board)
- `meta-evb-imx943-am` (machine config for i.MX943 Antmicro DC-SCM board)
- `meta-frdm-imx95` (machine config for i.MX95 15x15 FRDM board)
- `meta-evb-imx95-evk` (machine config for i.MX95 19x19 EVK board)
- `meta-imx91` (SoC-specific recipes for i.MX91)
- `meta-imx93` (SoC-specific recipes for i.MX93)
- `meta-imx943` (SoC-specific recipes for i.MX943)
- `meta-imx95` (SoC-specific recipes for i.MX95)

---

## 2. NXP Kernel / Dependent Trees

The BSP integrates the NXP Linux kernel:

```
- NXP Kernel Tree (public):
  URI:    https://github.com/nxp-qoriq/linux
  branch: lf-6.18.y-bmc
  commit: 1e60e29fabd077c7b8c1585f8c5815fdfaac57c2
```

> **Note:** The kernel source is selected by the `BMC_LINUX_USE_INTERNAL` flag
> in `conf/machine/include/nxp.inc`. The default is now `"0"`, which builds
> from the public GitHub tree shown above; set it to `"1"` in `local.conf` to
> build from the internal NXP Bitbucket mirror (requires SSH access to
> `bitbucket.sw.nxp.com`).
>
> ⚠️ **Migration note:** the default was previously `"1"`. Internal and CI
> builds that relied on the implicit internal mirror must now set
> `BMC_LINUX_USE_INTERNAL = "1"` explicitly, otherwise they will silently fetch
> from `github.com/nxp-qoriq/linux`, which fails on air-gapped build hosts.
>
> **Both** branches already carry every OpenBMC downstream kernel change, so
> the `linux-nxp` recipe applies no `*.patch` files in either case - only the
> OpenBMC `*.cfg` defconfig fragments are added. The same flag also selects the
> `bmc_mailbox` source (Bitbucket + `AUTOREV` when internal, public GitHub
> pinned to `BMC_MAILBOX_SRCREV_GITHUB` when external) and gates the
> internal-only OBMF packages.



Additional dependent components:

```
- NXP U-Boot:
  URI:    https://github.com/nxp-imx/uboot-imx
  branch: lf_v2026.04
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

| Machine | SoC | Board | Notes |
|---|---|---|---|
| `frdm-imx91` | i.MX91 | 11x11 FRDM | |
| `frdm-imx93` | i.MX93 | 11x11 FRDM | |
| `evk-imx93-nor` | i.MX93 | 11x11 EVK | NOR-flash (JFFS2) image variant. NOR boot is supported on the i.MX93 EVK board only (not FRDM). |
| `evb-imx943` | i.MX943 | 15x15 EVK | |
| `evb-imx943-am` | i.MX943 | Antmicro DC-SCM | |
| `frdm-imx95` | i.MX95 | 15x15 FRDM | |
| `evb-imx95-evk` | i.MX95 | 19x19 EVK | |
| `evb-imx95-evk-nor` | i.MX95 | 19x19 EVK | NOR-flash (JFFS2) image variant |
| `latu-dcsm-imx95` | i.MX95 | 19x19 LATU DC-SCM | Uses a dedicated kernel branch |

Machine definitions are under:
```
meta-nxp/meta-frdm-imx91/conf/machine/
meta-nxp/meta-frdm-imx93/conf/machine/
meta-nxp/meta-evb-imx943/conf/machine/
meta-nxp/meta-evb-imx943-am/conf/machine/
meta-nxp/meta-frdm-imx95/conf/machine/
meta-nxp/meta-evb-imx95-evk/conf/machine/
meta-nxp/meta-latu-dcsm-imx95/conf/machine/
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
. setup frdm-imx93
# or: frdm-imx91 / evb-imx943 / evb-imx943-am / frdm-imx95 / evb-imx95-evk
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

> **Note:** The WIC image will be available at
> `build/<machine>/tmp/deploy/images/<machine>/`

---

## 5. Flashing the Image to an SD Card / eMMC

The build produces a bzip2-compressed WIC image
(`obmc-phosphor-image-<machine>.wic.bz2`).

1. Insert the micro-SD card into your Linux host and identify the device node:
   ```bash
   lsblk
   ```
   > **Warning:** Double-check the device node (e.g. `/dev/sdX` or
   > `/dev/mmcblkX`). Writing to the wrong device can destroy host data.

2. Flash directly from the compressed image (no separate decompress step
   needed):
   ```bash
   sudo apt install bzip2
   cd build/<machine>/tmp/deploy/images/<machine>
   bunzip2 -c obmc-phosphor-image-<machine>-<timestamp>.wic.bz2 \
       | sudo dd of=/dev/<sd-card-device> bs=4M conv=fdatasync status=progress
   ```

   Alternatively, decompress first and then flash the `.wic`:
   ```bash
   bunzip2 obmc-phosphor-image-<machine>-<timestamp>.wic.bz2
   sudo dd if=obmc-phosphor-image-<machine>-<timestamp>.wic \
       of=/dev/<sd-card-device> bs=4M conv=fdatasync status=progress
   ```

---

## 6. First Boot and Bring-up

1. Set the board boot switches to boot from the SD card and power on. To reach
   the U-Boot / Linux serial console, connect a USB-C cable to the board's debug
   port and open a serial terminal on the host (115200 8N1):
   ```bash
   # using cu:
   sudo apt install cu
   cu -l /dev/ttyACM0 -s 115200

   # or with screen:
   screen /dev/ttyACM0 115200

   # or with minicom:
   minicom -D /dev/ttyACM0 -b 115200

   # If nothing appears, try /dev/ttyACM1, /dev/ttyACM2, ...
   ```

2. **(i.MX93 only)** If the default device tree is not the BMC variant, stop at
   U-Boot ("Hit any key to stop autoboot") and select the BMC device tree:
   ```bash
   setenv fdtfile imx93-11x11-frdm-bmc.dtb
   saveenv
   boot
   ```

3. Log in at the console with the default credentials (see
   [Section 8, Default Credentials & Hardening](#8-default-credentials--hardening)).

4. **Service state on boot.** Bringing the BMC/host state machine to the ready
   state and setting up the host console are handled automatically on every
   boot by the `bmc-init` recipe, which installs and auto-enables
   `bmc-state-change.service` and `bmc-console.service`. No manual step is
   required for these (they replace the former `state_change.sh` / `console.sh`
   helpers).

5. **One-time: disable non-applicable services.** On a freshly flashed image you
   may want to disable services that are not applicable to the board. The
   `scripts/disable_services.sh` helper in this layer is **not** installed onto
   the board, so copy it over (or run its commands directly on the board):
   ```bash
   # from the host, once the board has an IP (see Section 7):
   scp scripts/disable_services.sh root@<board-ip>:/tmp/

   # then on the board console / SSH:
   systemctl --failed            # inspect any failed services
   chmod +x /tmp/disable_services.sh && /tmp/disable_services.sh
   ```
   > **Note:** `disable_services.sh` disables `systemd-networkd-wait-online`,
   > `uart-render-controller`, and `trace-enable`, then reboots the board. It
   > only needs to be run once per freshly flashed image.

---

## 7. Accessing the OpenBMC Web UI

1. Connect the board's management Ethernet port (e.g. ENET2 / P4 on the i.MX93
   FRDM) to the same network as your host. An address is obtained via DHCP; for
   boards/interfaces that need to be brought up manually:
   ```bash
   udhcpc -i <interface>          # e.g. eth0
   ```

2. Read the assigned IPv4 address from the board console:
   ```bash
   ip addr show eth0
   # or (BusyBox also ships ifconfig): ifconfig eth0
   ```

3. From a browser on a host in the same network, open:
   ```
   https://<board-ip>
   ```
   Accept the self-signed-certificate warning if prompted
   ("Advanced" -> "Accept the Risk and Continue").

4. Log in with the default credentials (see
   [Section 8, Default Credentials & Hardening](#8-default-credentials--hardening)).

From the Web UI you can view sensors (**Hardware Status -> Sensors**), the host
serial console (**Overview -> SOL Console**), and perform power operations
(**Operations -> Server Power Operations**).

---

## 8. Default Credentials & Hardening

The image ships with a single default account for initial bring-up:

| Username | Password |
|---|---|
| `root` | `0penBmc`  _(the first character is a **zero**, not the letter O)_ |

> **Important:** These defaults are for initial access only. Change the
> credentials and harden remote access before connecting a board to any shared
> or production network.

### Change the default password

Over SSH or the serial console:
```bash
passwd root
```
Or via the Web UI: **Security and Access -> User Management**, then edit the
`root` user (or create a new privileged user and disable/rename `root`).

Over Redfish:
```bash
curl -k -u root -X PATCH \
  https://<board-ip>/redfish/v1/AccountService/Accounts/root \
  -H 'Content-Type: application/json' \
  -d '{"Password":"<new-strong-password>"}'
```
> **Tip:** Passing `-u root` (without the password) makes `curl` prompt for it
> interactively. Avoid putting the password inline (`-u root:<pw>`) — it would
> be visible in your shell history and in process listings. Use a prompt or a
> `--netrc` file instead.

### SSH hardening

- **Use key-based authentication** and disable password logins. This layer
  builds on the default OpenBMC/phosphor image, which uses **Dropbear** as its
  SSH server (not OpenSSH). Add your public key to `~/.ssh/authorized_keys`;
  Dropbear reads it automatically. To disable password authentication, set
  `DROPBEAR_EXTRA_ARGS="-s"` for the `dropbear` service, then restart it:
  ```bash
  systemctl restart dropbear
  ```
  > **Note:** If the image was rebuilt to use OpenSSH instead, configure
  > `/etc/ssh/sshd_config` (`PasswordAuthentication no`,
  > `PermitRootLogin prohibit-password`) and restart `sshd` instead.
- **Restrict management access** to a trusted management network / VLAN; do not
  expose the BMC directly to untrusted networks.
- **Replace the default self-signed TLS certificate** with a CA-signed
  certificate for the Web UI / Redfish (**Security and Access -> Certificates**,
  or via the Redfish `CertificateService`).
- **Rotate credentials** and disable any unused accounts and services after
  bring-up.

> Report suspected security vulnerabilities to the NXP Product Security Incident
> Response Team (PSIRT) at `PSIRT@nxp.com`.

---

## 9. Supported OpenBMC Features

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

## 10. FPGA Mailbox and the `mock_server` Simulator

On the DC-SCM topology the BMC reaches platform sensors, GPIOs, host power and
PLDM/MCTP through a Lattice FPGA "mailbox" over QSPI. Two packages provide this,
both built from the `bmc_mailbox` repo (source centralized in
`conf/machine/include/nxp.inc` as `BMC_MAILBOX_SRC`/`_BRANCH`/`_SRCREV`):

| Package | What it is |
|---|---|
| `qspi-mailbox` | Out-of-tree kernel driver `imx9-qspi-mailbox.ko`. Exposes the FPGA-backed subsystems as standard Linux interfaces (hwmon, virtual I2C/I3C, GPIO, PWM, IIO, eSPI, PLDM) so stock `dbus-sensors` / `entity-manager` bind unmodified. |
| `mock-server` | Userspace daemon `mock_server`. Plays the managed server **behind** the FPGA, so the whole stack can run with **no FPGA and no DC-SCM hardware**. |

Both install on all builds (internal and external). The OBMF USB/ICP packages
(`obmf-driver`, `obmf-bmc-apps`) remain internal-only.

### Running against real FPGA hardware

The driver binds automatically when the board's device tree contains the
mailbox node and the matching `*-mailbox-mock.dtbo` overlay is applied. Once
loaded, the FPGA sensors appear like any other hwmon/I2C device:

```bash
lsmod | grep imx9_qspi_mailbox
sensors                                   # FPGA-backed temps, voltages, fans
i2cdetect -y -r 20                        # a virtual FPGA I2C bus
cat /sys/class/hwmon/hwmon*/name          # imx9_fpga_mb = FPGA-internal channel
ls /sys/kernel/debug/*qspi*/              # stat_txn_ok, stat_crc_err, ...
```

No `mock_server` is needed in this mode - the driver talks to the real FPGA.

### Running without hardware (the simulator)

For bench/CI use the kernel is built with the userspace relay transport
(`CONFIG_IMX9_QSPI_MB_USPACE=y`), and `mock_server` answers the driver's mailbox
requests over `/dev/qspi-mb-sim<N>`. On the image it is started automatically by
`mock-server.service`; to run it by hand:

```bash
systemctl status mock-server           # the packaged service
# or run it directly, tracing every sensor access:
mock_server -s
```

Inject a threshold/alert without hardware by writing the live alarm file (the
daemon re-reads it on change), then watch the chain reach hwmon / Redfish:

```bash
# spike sensor 0x2000 to 127 C for 15 s at the top of every 60 s window
echo '0x2000 60 15 127' > /var/run/mock_server_alarm.txt
```

The operator guide `MOCK_SERVER_USER_GUIDE.md` (shipped under
`/usr/share/doc/mock_server/` on the image, alongside the alarm/values example
files) documents the sensor model, value pinning, every alert type, GPIO line
events, and the D-Bus / Redfish verification steps in full.

---

## 11. Directory Structure

```
meta-common/           Shared BSP code (meta-imx-bsp)
meta-frdm-imx91/       Machine config: i.MX91 FRDM
meta-frdm-imx93/       Machine config: i.MX93 FRDM
meta-evb-imx943/       Machine config: i.MX943 EVK
meta-evb-imx943-am/    Machine config: i.MX943 Antmicro DC-SCM
meta-frdm-imx95/       Machine config: i.MX95 15x15 FRDM
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

### Kernel Config Fragments (`recipes-kernel/linux/files/`)

> **Note:** The OpenBMC downstream kernel changes now live natively on both the
> internal and the public (`nxp-qoriq/linux`, `lf-6.18.y-bmc`) kernel branches,
> so the `linux-nxp` recipe **no longer applies any `file://*.patch`** - only
> the OpenBMC `*.cfg` defconfig fragments are added via `SRC_URI`. The obsolete
> patch files have been removed from this directory; the history is still
> available in git. See `conf/machine/include/nxp.inc`.



---

## 12. Troubleshooting & FAQ

| Symptom | Likely cause / fix |
|---|---|
| A package fails to build | Rebuild just that package: `bitbake -c cleansstate <package> && bitbake <package>`. |
| Nothing on the serial console | Try another device node (`/dev/ttyACM1`, `ttyACM2`, …) and confirm 115200 8N1; re-seat the USB-C cable. |
| Board does not boot from SD | Verify boot-switch settings for SD/eMMC boot and re-flash the WIC (check you wrote to the correct `/dev/` node). |
| i.MX93 boots wrong device tree | Stop at U-Boot and set `fdtfile imx93-11x11-frdm-bmc.dtb`, then `saveenv; boot`. |
| Failed services after first boot | Run the one-time `disable_services.sh` (see Section 6); BMC/host state and console are set automatically by `bmc-state-change.service` / `bmc-console.service`. |
| No IP address on the board | Ensure the management Ethernet port is used and on the same subnet; run `udhcpc -i eth0`, then `ip addr show eth0` (or `ifconfig eth0`). |
| Web UI unreachable / cert warning | Use `https://<board-ip>` (not `http`) and accept the self-signed certificate. |
| Login rejected | Default login is `root` / `0penBmc` — the first character is a **zero**. |
| iKVM not working on i.MX95 EVK / i.MX943 EVK | PCI-related rework is required; contact NXP support for the changes. |

### Where to Get Help

- **Related documentation:** *OpenBMC i.MX9x User Guide* (OpenBMC-IMX9x-UM) for
  end-to-end demo walkthroughs, hardware wiring, and per-board feature usage.
- **Security vulnerabilities:** contact the NXP Product Security Incident
  Response Team (PSIRT) at `PSIRT@nxp.com`.
- **General support:** contact your local NXP FAE or sales representative.

---

## License

This layer is provided under MIT and Apache 2.0 licenses as included with the
source tree.
