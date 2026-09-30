# -------------------------------------------------------------------
# packagegroup-obmc-apps.bbappend for evb-imx93-nor
# -------------------------------------------------------------------
# Remove debug/diagnostic devtools for NOR flash production builds.
# Gated by 'nor-size-reduction' so debug builds keep these tools.
#
#  ffdc         - first-failure data capture scripts
#  rsync        - file sync utility (no BMC service depends on it)
#  trace-enable - debug tracing helper
# -------------------------------------------------------------------
# Scoped to evb-imx93-nor so other iMX93 machines are never affected,
# even if they add 'nor-size-reduction' to their DISTRO_FEATURES.
RDEPENDS:${PN}-devtools:remove:evb-imx93-nor = "${@bb.utils.contains('DISTRO_FEATURES', 'nor-size-reduction', \
    'ffdc rsync trace-enable', '', d)}"
