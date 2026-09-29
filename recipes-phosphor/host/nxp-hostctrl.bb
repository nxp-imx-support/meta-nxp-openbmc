SUMMARY = "NXP Host Control Implementation"
DESCRIPTION = "Host power control (on / off / reset, graceful and force) for NXP iMX9 BMC platforms"
PR = "r2"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

inherit systemd
inherit obmc-phosphor-systemd

# busctl (systemd) publishes host state; libgpiod provides gpioset for the
# GPIO fallback transport when no eSPI sideband is present.
RDEPENDS:${PN} = "bash libgpiod-tools"
S = "${UNPACKDIR}"

SRC_URI = " \
           file://host-poweroff@.service \
           file://host-poweron@.service \
           file://nxp-host-force-poweroff@.service \
           file://nxp-host-graceful-reset@.service \
           file://nxp-host-force-reset@.service \
           file://nxp_host_power.sh \
           file://nxp_host_power_test.sh \
           file://nxp_host_check.sh \
           file://host_reboot.sh \
           file://poweroff.sh \
           file://poweron.sh \
          "

FILES:${PN} += " \
    ${systemd_system_unitdir}/host-poweron@.service \
    ${systemd_system_unitdir}/host-poweroff@.service \
    ${systemd_system_unitdir}/nxp-host-force-poweroff@.service \
    ${systemd_system_unitdir}/nxp-host-graceful-reset@.service \
    ${systemd_system_unitdir}/nxp-host-force-reset@.service \
"

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = " host-poweron@.service \
                          host-poweroff@.service \
                          nxp-host-force-poweroff@.service \
                          nxp-host-graceful-reset@.service \
                          nxp-host-force-reset@.service \
                        "
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# ---------------------------------------------------------------------------
# Target wiring
#
# OpenBMC distinguishes graceful from force by TARGET, and each target must be
# served by its own unit:
#
#   obmc-host-shutdown@N.target          graceful off  -> host-poweroff@N
#   obmc-chassis-poweroff@N.target       force off     -> nxp-host-force-poweroff@N
#   obmc-host-warm-reboot@N.target       graceful rst  -> nxp-host-graceful-reset@N
#   obmc-host-force-warm-reboot@N.target force rst     -> nxp-host-force-reset@N
#
# NOTE the deliberate absence of a link from obmc-host-force-warm-reboot into
# obmc-host-warm-reboot@N.target.requires. The previous revision had exactly
# that link, which meant a graceful restart request pulled in and ran the FORCE
# target - the reported "Graceful Restart performs a force restart instead"
# behaviour. Graceful now has its own implementation and escalates to the force
# target itself, via OnFailure and via an in-script timeout, rather than being
# unconditionally routed to it.
# ---------------------------------------------------------------------------

# Graceful warm reboot -> graceful reset unit
HOST_WARM_REBOOT_TGT = "nxp-host-graceful-reset@.service"
HOST_WARM_REBOOT_INSTMPL = "nxp-host-graceful-reset@{0}.service"
HOST_WARM_REBOOT_TGTFMT = "obmc-host-warm-reboot@{0}.target"
HOST_WARM_REBOOT_TARGET_FMT = "../${HOST_WARM_REBOOT_TGT}:${HOST_WARM_REBOOT_TGTFMT}.requires/${HOST_WARM_REBOOT_INSTMPL}"
SYSTEMD_LINK:${PN} += "${@compose_list_zip(d, 'HOST_WARM_REBOOT_TARGET_FMT', 'OBMC_HOST_INSTANCES')}"

# Force warm reboot -> force reset unit
HOST_WARM_REBOOT_FORCE_TGT = "nxp-host-force-reset@.service"
HOST_WARM_REBOOT_FORCE_INSTMPL = "nxp-host-force-reset@{0}.service"
HOST_WARM_REBOOT_FORCE_TGTFMT = "obmc-host-force-warm-reboot@{0}.target"
HOST_WARM_REBOOT_FORCE_TARGET_FMT = "../${HOST_WARM_REBOOT_FORCE_TGT}:${HOST_WARM_REBOOT_FORCE_TGTFMT}.requires/${HOST_WARM_REBOOT_FORCE_INSTMPL}"
SYSTEMD_LINK:${PN} += "${@compose_list_zip(d, 'HOST_WARM_REBOOT_FORCE_TARGET_FMT', 'OBMC_HOST_INSTANCES')}"

# Host start -> power on
HOST_POWER_ON_HOSTTMPL = "host-poweron@.service"
HOST_POWER_ON_HOSTINSTMPL = "host-poweron@{0}.service"
HOST_POWER_ON_HOSTTGTFMT = "obmc-host-startmin@{0}.target"
HOST_POWER_ON_HOSTFMT = "../${HOST_POWER_ON_HOSTTMPL}:${HOST_POWER_ON_HOSTTGTFMT}.requires/${HOST_POWER_ON_HOSTINSTMPL}"
SYSTEMD_LINK:${PN} += "${@compose_list_zip(d, 'HOST_POWER_ON_HOSTFMT', 'OBMC_HOST_INSTANCES')}"

# Graceful host shutdown -> graceful power off
HOST_POWER_OFF_HOSTTMPL = "host-poweroff@.service"
HOST_POWER_OFF_HOSTINSTMPL = "host-poweroff@{0}.service"
HOST_POWER_OFF_HOSTTGTFMT = "obmc-host-shutdown@{0}.target"
HOST_POWER_OFF_HOSTFMT = "../${HOST_POWER_OFF_HOSTTMPL}:${HOST_POWER_OFF_HOSTTGTFMT}.requires/${HOST_POWER_OFF_HOSTINSTMPL}"
SYSTEMD_LINK:${PN} += "${@compose_list_zip(d, 'HOST_POWER_OFF_HOSTFMT', 'OBMC_HOST_INSTANCES')}"

# Force chassis power off -> force power off
HOST_FORCE_OFF_TMPL = "nxp-host-force-poweroff@.service"
HOST_FORCE_OFF_INSTMPL = "nxp-host-force-poweroff@{0}.service"
HOST_FORCE_OFF_TGTFMT = "obmc-chassis-poweroff@{0}.target"
HOST_FORCE_OFF_FMT = "../${HOST_FORCE_OFF_TMPL}:${HOST_FORCE_OFF_TGTFMT}.requires/${HOST_FORCE_OFF_INSTMPL}"
SYSTEMD_LINK:${PN} += "${@compose_list_zip(d, 'HOST_FORCE_OFF_FMT', 'OBMC_HOST_INSTANCES')}"

do_install() {
    install -d ${D}${sbindir}
    install -d ${D}${systemd_system_unitdir}

    # Shared library, sourced by all of the scripts below.
    install -m 0755 ${UNPACKDIR}/nxp_host_power.sh ${D}${sbindir}/

    # Self-test. Exercises graceful vs force, the escalation-on-timeout path
    # and the state-publication ordering against a modelled host, with no FPGA
    # and no real host - so the logic is testable on imx93 / imx943 / imx95,
    # which have no mailbox, as well as on imx91.
    install -m 0755 ${UNPACKDIR}/nxp_host_power_test.sh ${D}${sbindir}/

    install -m 0755 ${UNPACKDIR}/nxp_host_check.sh ${D}${sbindir}/
    install -m 0755 ${UNPACKDIR}/poweron.sh ${D}${sbindir}/
    install -m 0755 ${UNPACKDIR}/poweroff.sh ${D}${sbindir}/
    install -m 0755 ${UNPACKDIR}/host_reboot.sh ${D}${sbindir}/

    install -m 0644 ${UNPACKDIR}/host-poweron@.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/host-poweroff@.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/nxp-host-force-poweroff@.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/nxp-host-graceful-reset@.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/nxp-host-force-reset@.service ${D}${systemd_system_unitdir}/
}

pkg_postinst:${PN}() {
    exit 0
}
