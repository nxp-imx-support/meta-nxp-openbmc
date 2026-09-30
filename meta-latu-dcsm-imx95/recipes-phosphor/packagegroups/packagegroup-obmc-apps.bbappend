# -------------------------------------------------------------------
# packagegroup-obmc-apps.bbappend for latu-dcsm-imx95
# -------------------------------------------------------------------
# Remove debug/diagnostic devtools for NOR flash production builds.
# Gated by 'nor-size-reduction' so debug builds keep these tools.
#
#  ffdc         - first-failure data capture scripts
#  rsync        - file sync utility (no BMC service depends on it)
#  trace-enable - debug tracing helper
# -------------------------------------------------------------------
RDEPENDS:${PN}-devtools:remove = "${@bb.utils.contains('DISTRO_FEATURES', 'nor-size-reduction', \
    'ffdc rsync trace-enable', '', d)}"
