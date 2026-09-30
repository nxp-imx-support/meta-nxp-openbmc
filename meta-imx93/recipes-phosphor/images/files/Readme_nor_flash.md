# NOR Flash Programming via UUU (i.MX93 EVK)

## Required Files

The following files must be in the same directory:

- `flash_nor_uuu.auto` - UUU script for NOR flash programming
- `imx-boot-evb-imx93-nor-fspi.bin-flash_singleboot` - Bootloader image
- `obmc-phosphor-image-evb-imx93-nor.norflash` - Consolidated NOR flash image

## Usage

**Linux:**
```
sudo uuu flash_nor_uuu.auto
```

**Windows:**
```
uuu.exe flash_nor_uuu.auto
```

## NOR Partition Layout

| Partition | Offset     | Size       | Description              |
|-----------|------------|------------|--------------------------|
| boot      | 0x0000000  | 2.75 MB    | imx-boot container       |
| kernel    | 0x02C0000  | 14.25 MB   | Linux kernel (Image.gz)  |
| dtb       | 0x1200000  | 512 KB     | Device tree blob         |
| rootfs    | 0x1280000  | 40.5 MB    | JFFS2 root filesystem    |
| **total** | -          | **59 MB**  | 0x3B00000                |

## Notes

- Connect the board via USB in serial download (SDP/SDPS) mode before running.
- UUU version 1.5.233 or later is required.
- The script first flashes the boot container (with FlexSPI header init),
  then writes the full consolidated NOR image.
- NOR flash erase and write of 59 MB takes several minutes -- be patient.
- NOR flash device: Micron mt25qu512a (64 MB, 4 KB erase block).
