# NOR Flash Programming Guide - evk-imx943-am

## Overview

The `norflash` image type produces a single flat binary
(`obmc-phosphor-image-evk-imx943-am.norflash`) that can be written directly
to the SPI NOR flash on the evk-imx943-am board.

## NOR Flash Partition Layout

| Partition | Offset     | Size       | Contents                              |
|-----------|------------|------------|---------------------------------------|
| u-boot    | 0x00000000 | 0x002E0000 | imx-boot container (flash.bin)        |
| kernel    | 0x002E0000 | 0x02300000 | Linux kernel Image                    |
| dtb       | 0x025E0000 | 0x00020000 | imx943-dc-scm.dtb                     |
| rootfs    | 0x02600000 | 0x03C00000 | JFFS2 root filesystem                 |
| **total** | **0x06200000** | **~98 MB** |                                   |

## Flashing via UUU (USB Serial Download)

Requirements:
- UUU tool (version >= 1.5.233): https://github.com/nxp-imx/mfgtools
- Board in USB serial download mode (hold boot mode pins, connect USB OTG)

Place the following files in the same directory and run:

```
uuu flash_nor_uuu.auto
```

Required files:
- `flash_nor_uuu.auto`
- `imx-boot-evk-imx943-am-xspi.bin-flash_a55_xspi`
- `obmc-phosphor-image-evk-imx943-am.norflash`

## Flashing via Linux (running on the board)

```bash
dd if=obmc-phosphor-image-evk-imx943-am.norflash of=/dev/mtd0 bs=4096
```

## Flashing via U-Boot (TFTP)

```
tftp ${loadaddr} obmc-phosphor-image-evk-imx943-am.norflash
sf probe
sf erase 0 0x6200000
sf write ${loadaddr} 0 ${filesize}
```
