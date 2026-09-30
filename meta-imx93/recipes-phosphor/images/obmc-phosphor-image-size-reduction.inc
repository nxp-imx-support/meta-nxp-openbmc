# -------------------------------------------------------------------
# obmc-phosphor-image-size-reduction.inc
# -------------------------------------------------------------------
# Rootfs size-reduction policy for the evb-imx93-nor NOR flash BMC.
# Rootfs partition: 39.75 MB (0x027C0000) after squeeze from 56 MB.
# This file is conditionally included by obmc-phosphor-image.bbappend
# when DISTRO_FEATURES contains 'nor-size-reduction' (production default).
#
# To build a debug image with all tools present, remove the feature:
#   DISTRO_FEATURES:remove = "nor-size-reduction"
# -------------------------------------------------------------------

# ===================================================================
# Package-level removal
# ===================================================================

# --- Tier 0: large packages not needed on NOR-flash BMC ---
#
#  v4l-utils          ~2.5 MB  - V4L2/CEC diagnostic tools; obmc-ikvm uses
#                                direct ioctl(), not v4l-utils.
#  rsync              ~532 KB  - No systemd unit launches rsyncd at boot; not
#                                required for any core BMC service.
#  lm-sensors-scripts ~252 KB  - Perl scripts (sensors-detect, fancontrol).
#                                phosphor-hwmon does not call these at runtime.
#                                Removing them eliminates the perl/libperl
#                                dependency (~4.9 MB libperl + 1.2 MB modules).
#  perl               ~4.9 MB  - Only pulled in by lm-sensors-scripts; safe to
#                                drop once lm-sensors-scripts is removed.
#  cracklib           ~768 KB  - Password-strength dictionary; no PAM config
#                                in this image references pam_cracklib.so.
#
# --- Tier 1: safe removal, no functionality loss ---
#  ipmitool           - CLI debug utility; ipmid/netipmid do not depend on it.
#  phosphor-debug-collector - BMC dump/debug service; not needed at runtime.
#
# --- Tier 3: trade-offs accepted for size ---
#  pldmtool           - CLI diagnostic for pldmd; removal does not affect pldmd.
#  dreport            - KEPT: debug log collection scripts retained for diagnostics.
#
# --- Tier 4: debug/diagnostic tools not needed for production ---
#  lrzsz              - serial XMODEM/ZMODEM debug utility.
#  nbd-client/nbd     - Network Block Device; not used on NOR-flash BMC.
#  openipmi           - OpenIPMI library; phosphor-host-ipmid provides IPMI.
#  xz                 - compression utility; not needed at runtime.
#  jsnbd              - JSON NBD server; debug utility.
#  openssh-sftp-server - SFTP server; dropbear replaces openssh.
IMAGE_INSTALL:remove:evb-imx93-nor = " \
    v4l-utils \
    rsync \
    lm-sensors-scripts \
    perl \
    cracklib \
    ipmitool \
    phosphor-debug-collector \
    pldmtool \
    lrzsz \
    nbd-client \
    openipmi \
    nbd \
    xz \
    jsnbd \
    openssh-sftp-server \
"

# ===================================================================
# SSH server swap: dropbear (~400 KB) replaces openssh (~2.5 MB)
# ===================================================================
IMAGE_FEATURES:remove:evb-imx93-nor = "ssh-server-openssh"
IMAGE_FEATURES:append:evb-imx93-nor = " ssh-server-dropbear"

# ===================================================================
# Compiler optimization: -Os (optimize for size)
# ===================================================================
# Switch from the default -O2 to -Os for all target recipes.
# -Os enables all -O2 optimizations that do not increase code size and
# activates size-focused inlining heuristics.  Typical binary size
# reduction is 10-25%.  Runtime overhead is negligible for BMC workloads
# (D-Bus, REST API, sensor polling are I/O-bound, not CPU-bound).
#
# NOTE: -Os is applied globally.  If timing-sensitive services
# (e.g. phosphor-watchdog, ipmid, pldmd) show regressions, override
# per-recipe with FULL_OPTIMIZATION:pn-<recipe> = "-O2 -pipe ${DEBUG_FLAGS}"
FULL_OPTIMIZATION:evb-imx93-nor = "-Os -pipe ${DEBUG_FLAGS}"

# ===================================================================
# Build-time stripping and locale removal
# ===================================================================

# Strip ELF binaries; set explicitly so stripping is not accidentally
# disabled by another layer.
INHIBIT_PACKAGE_STRIP:evb-imx93-nor = "0"
INHIBIT_PACKAGE_DEBUG_SPLIT:evb-imx93-nor = "0"

# Remove locale data - BMC firmware does not need i18n support.
IMAGE_LINGUAS:evb-imx93-nor = ""

# ===================================================================
# ROOTFS_POSTPROCESS_COMMAND functions
# ===================================================================

# --- entity-manager vendor configs (~6.4 MB) ---
# Remove all vendor subdirectories; the iMX93 EVK uses only the
# top-level flat JSON files under configurations/.
remove_entity_manager_vendor_configs () {
    find ${IMAGE_ROOTFS}/usr/share/entity-manager/configurations \
        -mindepth 1 -maxdepth 1 -type d \
        -exec rm -rf {} +
}
ROOTFS_POSTPROCESS_COMMAND:append:evb-imx93-nor = " remove_entity_manager_vendor_configs;"

# --- PLDM PDR vendor definitions (~1.8 MB) ---
# The iMX95 BMC does not ship pre-built PDR entries; pldmd discovers
# PDRs from the endpoint at runtime via the PLDM protocol.
remove_pldm_vendor_pdrs () {
    rm -rf ${IMAGE_ROOTFS}/usr/share/pldm/pdr
    mkdir -p ${IMAGE_ROOTFS}/usr/share/pldm/pdr
}
ROOTFS_POSTPROCESS_COMMAND:append:evb-imx93-nor = " remove_pldm_vendor_pdrs;"

# --- Redfish schema removal (~5.2 MB uncompressed) ---
# Remove ALL Redfish JSON and XML schema files.  bmcweb serves Redfish
# resources dynamically; the on-disk schemas are only used for the
# $metadata and JsonSchemas endpoints.  Removing them saves significant
# flash space; bmcweb will return 404 for schema download requests.
#
# KNOWN LIMITATION: Redfish clients that fetch $metadata or JsonSchemas
# at startup (e.g. DMTF validators, iDRAC) may report non-compliance
# or abort sessions due to 404 responses.  This is an accepted trade-off
# for NOR flash size constraints.
remove_all_redfish_schemas () {
    rm -rf ${IMAGE_ROOTFS}/usr/share/www/redfish/v1/JsonSchemas 2>/dev/null || true
    rm -rf ${IMAGE_ROOTFS}/usr/share/www/redfish/v1/schema 2>/dev/null || true
    mkdir -p ${IMAGE_ROOTFS}/usr/share/www/redfish/v1/JsonSchemas
    mkdir -p ${IMAGE_ROOTFS}/usr/share/www/redfish/v1/schema
}
ROOTFS_POSTPROCESS_COMMAND:append:evb-imx93-nor = " remove_all_redfish_schemas;"

# --- Binary-level cleanup ---
# Remove debug/diagnostic binaries that could not be excluded via
# IMAGE_INSTALL:remove (pulled in as dependencies or sub-packages).
remove_debug_binaries () {
    # --- Binary debug tools ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/filan
    rm -f ${IMAGE_ROOTFS}/usr/bin/procan
    # Kept: systemd-coredump and coredumpctl are required for crash diagnostics
    rm -f ${IMAGE_ROOTFS}/usr/bin/lrz
    rm -f ${IMAGE_ROOTFS}/usr/bin/lsz
    rm -f ${IMAGE_ROOTFS}/usr/bin/rz ${IMAGE_ROOTFS}/usr/bin/sz
    rm -f ${IMAGE_ROOTFS}/usr/bin/rb ${IMAGE_ROOTFS}/usr/bin/sb
    # Kept: netipmid is required for IPMI over LAN
    rm -f ${IMAGE_ROOTFS}/usr/sbin/nbd-client
    rm -f ${IMAGE_ROOTFS}/usr/lib/libOpenIPMI*
    rm -f ${IMAGE_ROOTFS}/usr/lib/libnetsnmp*
    rm -f ${IMAGE_ROOTFS}/usr/bin/curl
    # systemd-analyze: boot profiling debug tool
    rm -f ${IMAGE_ROOTFS}/usr/bin/systemd-analyze

    # Kept: socat is removed below in orphaned service binaries section

    # --- telemetry: KEPT - phosphor-telemetry is installed in this image ---

    # --- Network debug utilities ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/ethtool
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ethtool
    rm -f ${IMAGE_ROOTFS}/usr/bin/tcpdump
    rm -f ${IMAGE_ROOTFS}/usr/sbin/tcpdump
    rm -f ${IMAGE_ROOTFS}/usr/bin/iperf3
    rm -f ${IMAGE_ROOTFS}/usr/bin/traceroute
    rm -f ${IMAGE_ROOTFS}/usr/bin/tracepath
    rm -f ${IMAGE_ROOTFS}/usr/bin/arping
    rm -f ${IMAGE_ROOTFS}/usr/sbin/arp

    # --- Block device utilities (NOR flash BMC has no block devices) ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkswap.util-linux
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkswap
    rm -f ${IMAGE_ROOTFS}/usr/sbin/swapon
    rm -f ${IMAGE_ROOTFS}/usr/sbin/swapoff
    rm -f ${IMAGE_ROOTFS}/usr/sbin/blkid
    rm -f ${IMAGE_ROOTFS}/usr/sbin/blockdev
    rm -f ${IMAGE_ROOTFS}/usr/sbin/fdisk
    rm -f ${IMAGE_ROOTFS}/usr/sbin/sfdisk
    rm -f ${IMAGE_ROOTFS}/usr/bin/lsblk
    rm -f ${IMAGE_ROOTFS}/usr/sbin/losetup
    rm -f ${IMAGE_ROOTFS}/usr/sbin/partprobe

    # --- Filesystem tools except jffs2 (ext4, ubifs, btrfs, xfs) ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mke2fs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.ext4
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.ext3
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.ext2
    rm -f ${IMAGE_ROOTFS}/usr/sbin/e2fsck
    rm -f ${IMAGE_ROOTFS}/usr/sbin/fsck.ext4
    rm -f ${IMAGE_ROOTFS}/usr/sbin/fsck.ext3
    rm -f ${IMAGE_ROOTFS}/usr/sbin/fsck.ext2
    rm -f ${IMAGE_ROOTFS}/usr/sbin/tune2fs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/resize2fs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/dumpe2fs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/debugfs
    rm -f ${IMAGE_ROOTFS}/usr/lib/libext2fs*
    rm -f ${IMAGE_ROOTFS}/usr/lib/libe2p*
    # Kept: libcom_err is used by other system libraries
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.ubifs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubinfo
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubiattach
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubidetach
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubimkvol
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubirmvol
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubiupdatevol
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubinize
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ubirename
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.btrfs
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mkfs.xfs

    # --- libperl: perl runtime library (~3.8 MB); no perl needed at runtime ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libperl.so*
    rm -rf ${IMAGE_ROOTFS}/usr/lib/perl5

    # --- sensors-detect: perl lm-sensors script ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/sensors-detect

    # --- libunistring: removed with GLib/GIO stack below (orphaned,
    # verified not loaded by any process on live BMC 2026-09-11). ---

    # Kept: coredump systemd units must remain to avoid boot failures

    # --- Documentation, man pages, debug symbols (not needed on BMC) ---
    rm -rf ${IMAGE_ROOTFS}/usr/share/man
    rm -rf ${IMAGE_ROOTFS}/usr/share/doc
    rm -rf ${IMAGE_ROOTFS}/usr/share/info
    rm -rf ${IMAGE_ROOTFS}/usr/lib/debug
    rm -rf ${IMAGE_ROOTFS}/usr/src/debug

    # --- Locale and i18n data ---
    rm -rf ${IMAGE_ROOTFS}/usr/share/locale
    rm -rf ${IMAGE_ROOTFS}/usr/share/i18n
    rm -rf ${IMAGE_ROOTFS}/usr/lib/locale

    # --- Timezone compilation tools (zoneinfo data kept) ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/zic
    rm -f ${IMAGE_ROOTFS}/usr/bin/zdump
    rm -f ${IMAGE_ROOTFS}/usr/bin/tzselect

    # --- Misc debug/admin tools not needed on BMC ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/ldd
    rm -f ${IMAGE_ROOTFS}/usr/bin/getconf
    rm -f ${IMAGE_ROOTFS}/usr/bin/locale
    rm -f ${IMAGE_ROOTFS}/usr/bin/iconv
    rm -f ${IMAGE_ROOTFS}/usr/bin/gencat
    rm -f ${IMAGE_ROOTFS}/usr/bin/sprof
    rm -f ${IMAGE_ROOTFS}/usr/sbin/iconvconfig
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ldconfig
    rm -f ${IMAGE_ROOTFS}/usr/bin/pldd
    rm -f ${IMAGE_ROOTFS}/usr/bin/sotruss
    rm -f ${IMAGE_ROOTFS}/usr/bin/mtrace

    # --- Python cache and test data if any ---
    find ${IMAGE_ROOTFS}/usr/lib/python3* -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find ${IMAGE_ROOTFS}/usr/lib/python3* -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
    find ${IMAGE_ROOTFS}/usr/lib/python3* -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true

    # --- Unused gconv charset modules (keep UTF-8 only) ---
    find ${IMAGE_ROOTFS}/usr/lib/gconv -type f ! -name "UTF*" ! -name "gconv-modules*" -delete 2>/dev/null || true

    # --- Orphaned service binaries ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/socat
    rm -f ${IMAGE_ROOTFS}/usr/bin/socat1
    rm -f ${IMAGE_ROOTFS}/usr/libexec/sftp-server 2>/dev/null || true

    # --- opkg package manager database (~960 KB) ---
    rm -rf ${IMAGE_ROOTFS}/usr/lib/opkg 2>/dev/null || true

    # --- kernel module metadata (~900 KB) - modprobe only needs modules.dep ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/modules/*/modules.builtin.modinfo 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/modules/*/modules.builtin.alias.bin 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/modules/*/modules.builtin 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/modules/*/modules.builtin.bin 2>/dev/null || true

    # --- cracklib data + libs (~750 KB) ---
    rm -rf ${IMAGE_ROOTFS}/usr/share/cracklib
    rm -f ${IMAGE_ROOTFS}/usr/lib/libcrack.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_cracklib.so 2>/dev/null || true

    # --- libpcap (~322 KB) - only used by tcpdump which is removed ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libpcap.so* 2>/dev/null || true

    # --- libsmartcols (~330 KB) - used by lsblk/fdisk which are removed ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libsmartcols.so* 2>/dev/null || true

    # --- Orphaned GLib/GIO stack (~6.4 MB) ---
    # libgio, libglib, libgobject, libunistring, libpcre2-8: the entire
    # GLib/GIO stack is orphaned on this image.  No binary or shared
    # library links to any of them (verified via readelf -d on all ELF
    # files and /proc/*/maps on the live BMC 2026-09-11).
    # They were pulled in as transitive dependencies of packages that
    # have since been removed (e.g. NetworkManager, glib-networking).
    #
    # WARNING: This verification is build-specific.  If recipe versions
    # change, new binaries may link these libraries.  CI should run
    # readelf -d on all installed ELF files to assert no dangling
    # DT_NEEDED entries before releasing the image.
    rm -f ${IMAGE_ROOTFS}/usr/lib/libgio-2.0.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libglib-2.0.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libgobject-2.0.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libgmodule-2.0.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libgthread-2.0.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libunistring.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libpcre2-8.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libpcre2-posix.so* 2>/dev/null || true
    rm -rf ${IMAGE_ROOTFS}/usr/share/glib-2.0 2>/dev/null || true

    # --- libxml2 (~1.3 MB) - no binary or .so links to it ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libxml2.so* 2>/dev/null || true

    # --- libdbus-1 (~386 KB) - OpenBMC uses sd-bus, not libdbus ---
    # WARNING: Some services (avahi, phosphor-network) may link libdbus-1
    # in certain build configurations.  Verify with readelf -d in CI.
    rm -f ${IMAGE_ROOTFS}/usr/lib/libdbus-1.so* 2>/dev/null || true

    # --- libreadline (~407 KB) - bash does not link it on this image ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libreadline.so* 2>/dev/null || true

    # --- libpwquality (~100 KB) - password quality checker ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libpwquality.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_pwquality.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/etc/security/pwquality.conf* 2>/dev/null || true

    # --- Unused PAM modules ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_lastlog.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_motd.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_mail.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_issue.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_ftp.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_rhosts.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_debug.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_tally2.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_filter.so 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/security/pam_access.so 2>/dev/null || true

    # --- net-tools legacy binaries ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/plipconfig.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/mii-tool.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/slattach.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/rarp.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/nameif.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/arp.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/ipmaddr.net-tools 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/iptunnel.net-tools 2>/dev/null || true

    # --- PAM timestamp check ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/pam_timestamp_check 2>/dev/null || true

    # --- cracklib tools ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/cracklib-check 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/cracklib-format 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/cracklib-packer 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/cracklib-unpacker 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/cracklib-update 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/create-cracklib-dict 2>/dev/null || true

    # --- USB/input debug tools ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/usbhid-dump 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/mouse-dpi-tool 2>/dev/null || true

    # --- coredumpctl debug viewer ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/coredumpctl 2>/dev/null || true

    # --- Unused systemd helper binaries (NOR flash BMC) ---
    # systemd-validatefs: filesystem validation - not used
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-validatefs 2>/dev/null || true
    # systemd-growfs: grow filesystem on block device - no block devices
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-growfs 2>/dev/null || true
    # systemd-battery-check: laptop battery check - no battery on BMC
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-battery-check 2>/dev/null || true

    # --- udev helpers for SCSI/ATA (no SCSI/ATA on NOR flash BMC) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/udev/scsi_id 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/udev/ata_id 2>/dev/null || true

    # --- eeprog: EEPROM programmer debug tool ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/eeprog 2>/dev/null || true

    # --- swap utilities (no swap on NOR flash BMC) ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/swapon.util-linux 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/swapoff.util-linux 2>/dev/null || true

    # --- varlinkctl: Varlink debug tool ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/varlinkctl 2>/dev/null || true

    # --- xz/lzma remnant binaries (xz package removed but sub-binaries persist) ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/xz 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzcat 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzdec 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzcmp 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzgrep 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzfgrep 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzegrep 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzdiff 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzless 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/xzmore 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/lzma 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/lzmadec 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/lzmainfo 2>/dev/null || true

    # --- Shadow/password admin tools not needed at runtime ---
    rm -f ${IMAGE_ROOTFS}/usr/sbin/vipw.shadow 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/groupmems 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/grpck 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/pwck 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/chgpasswd 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/pwconv 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/pwunconv 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/grpconv 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/grpunconv 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/sbin/logoutd 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/faillog 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/expiry 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/newuidmap 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/newgidmap 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/getsubids 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/pwscore 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/pwmake 2>/dev/null || true

    # --- Input device debug tools (no touchpad/input devices on BMC) ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/touchpad-edge-detector 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/bin/libevdev-tweak-device 2>/dev/null || true

    # --- systemd-pstore: persistent storage for kernel crash logs - not used ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-pstore 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-pstore.service 2>/dev/null || true

    # --- systemd-fsck: filesystem check - JFFS2 does not use fsck ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-fsck 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-fsck-root.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-fsck@.service 2>/dev/null || true

    # --- systemd-volatile-root (~66 KB): volatile root overlay - not used on NOR BMC ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-volatile-root 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-volatile-root.service 2>/dev/null || true

    # --- systemd-time-wait-sync (~66 KB): NTP time sync wait - not used ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-time-wait-sync 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-time-wait-sync.service 2>/dev/null || true

    # --- systemd-tty-ask-password-agent (~66 KB): interactive password prompts - headless BMC ---
    rm -f ${IMAGE_ROOTFS}/usr/bin/systemd-tty-ask-password-agent 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-ask-password-console.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-ask-password-wall.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-ask-password-console.path 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-ask-password-wall.path 2>/dev/null || true

    # --- systemd-factory-reset (~66 KB): factory reset - not used on this BMC ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-factory-reset 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-factory-reset-complete.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-factory-reset-reboot.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-factory-reset-request.service 2>/dev/null || true

    # --- systemd-boot-check-no-failures (~66 KB): boot success check - not used ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-boot-check-no-failures 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-boot-check-no-failures.service 2>/dev/null || true

    # --- systemd-hostnamed (~66 KB): hostname service - inactive/dead on live BMC ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-hostnamed 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-hostnamed.service 2>/dev/null || true

    # --- phosphor-ramoops-monitor (~66 KB): debug-collector orphan - inactive/dead ---
    rm -f ${IMAGE_ROOTFS}/usr/libexec/phosphor-debug-collector/phosphor-ramoops-monitor 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/ramoops-monitor.service 2>/dev/null || true

    # --- initrd services (NOR flash boots directly, no initrd) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/initrd-cleanup.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/initrd-parse-etc.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/initrd-switch-root.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/initrd-udevadm-cleanup-db.service 2>/dev/null || true

    # --- systemd-soft-reboot: userspace-only reboot - not used ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-soft-reboot.service 2>/dev/null || true

    # --- systemd-battery-check unit file (binary already removed above) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-battery-check.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/initrd.target.wants/systemd-battery-check.service 2>/dev/null || true

    # ================================================================
    # Additional removals verified against live BMC /proc/*/maps
    # (verified on iMX93 EVK, 2026-09-09)
    # ================================================================

    # --- libcurl (~725 KB): curl binary already removed; bmcweb does NOT
    #     link libcurl (confirmed: not in any process memory maps) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libcurl.so* 2>/dev/null || true

    # --- libfreetype + libfontconfig (~1,118 KB combined): font rendering
    #     libraries. obmc-ikvm uses libjpeg + libvncserver but does NOT
    #     load freetype/fontconfig (confirmed via /proc/5637/maps) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/libfreetype.so* 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/libfontconfig.so* 2>/dev/null || true
    rm -rf ${IMAGE_ROOTFS}/usr/share/fontconfig 2>/dev/null || true
    rm -rf ${IMAGE_ROOTFS}/etc/fonts 2>/dev/null || true
    rm -rf ${IMAGE_ROOTFS}/usr/share/fonts 2>/dev/null || true

    # --- librrd (~268 KB): RRD database library. health-monitor is running
    #     but does NOT load librrd (confirmed via /proc/314/maps) ---
    rm -f ${IMAGE_ROOTFS}/usr/lib/librrd.so* 2>/dev/null || true

    # --- Unused systemd helper binaries (~68 KB each, ~476 KB total) ---
    # None of these appear in /proc/*/maps on the live BMC.
    # systemd-storagetm: NVMe storage target mode - no NVMe on BMC
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-storagetm 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-storagetm.service 2>/dev/null || true
    # systemd-ssh-issue: SSH login banner - using dropbear, not openssh
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-ssh-issue 2>/dev/null || true
    # systemd-ssh-proxy: SSH proxy helper - not used
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-ssh-proxy 2>/dev/null || true
    # systemd-makefs: create filesystems on block devices - no block devices
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-makefs 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-makefs@.service 2>/dev/null || true
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-mkswap@.service 2>/dev/null || true
    # systemd-reply-password: password agent helper - headless BMC
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-reply-password 2>/dev/null || true
    # systemd-sulogin-shell: single-user/emergency shell helper
    # NOTE: emergency.service and rescue.service are KEPT - systemd has
    # hardcoded references and may panic at boot if they are missing.
    #rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-sulogin-shell 2>/dev/null || true
    # systemd-network-generator: generates networkd config from kernel cmdline
    #rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/systemd-network-generator 2>/dev/null || true
    #rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/systemd-network-generator.service 2>/dev/null || true

    # --- Unused systemd generators (~68 KB each, ~272 KB total) ---
    # systemd-debug-generator: enables debug shell from kernel cmdline
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system-generators/systemd-debug-generator 2>/dev/null || true
    # systemd-factory-reset-generator: factory reset flow (binary already removed above)
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system-generators/systemd-factory-reset-generator 2>/dev/null || true
    # systemd-system-update-generator: offline system update mode
    rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system-generators/systemd-system-update-generator 2>/dev/null || true
    # systemd-ssh-generator: auto-generates sshd socket units - using dropbear
    #rm -f ${IMAGE_ROOTFS}/usr/lib/systemd/system-generators/systemd-ssh-generator 2>/dev/null || true
}
ROOTFS_POSTPROCESS_COMMAND:append:evb-imx93-nor = " remove_debug_binaries;"
