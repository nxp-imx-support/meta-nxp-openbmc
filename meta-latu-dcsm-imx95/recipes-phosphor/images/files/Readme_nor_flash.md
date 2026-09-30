# NOR Flash Programming via UUU (i.MX95 LATU-DCSM)

## Required Files

The following files must be in the same directory:

- `flash_nor_uuu.auto` - UUU script for NOR flash programming
- `imx-boot-latu-dcsm-imx95-fspi.bin-flash_a55_flexspi` - Bootloader image
- `obmc-phosphor-image-latu-dcsm-imx95.norflash` - NOR flash image

## Usage

**Linux:**
```
uuu flash_nor_uuu.auto
```

**Windows:**
```
uuu.exe flash_nor_uuu.auto
```

## Notes

- Connect the board via USB in serial download (SDP) mode before running the command.
- UUU version 1.5.233 or later is required.
- The script will boot the board, erase NOR flash, and write the full norflash image.
