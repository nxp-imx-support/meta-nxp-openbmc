SUMMARY = "Managed-server simulator for the FPGA mailbox (mock_server)"
DESCRIPTION = "Userspace daemon that plays the managed server behind the \
MachXO5 FPGA. It presents several protocol faces onto one model: the \
imx9-qspi-mailbox relay character device (/dev/qspi-mb-sim*), a PLDM-over-MCTP \
terminus, and the OpenBMC D-Bus surfaces (phosphor-logging event entries, \
State.Boot.Raw POST codes, and Inventory.Manager host FRU objects). This \
replaces the earlier split of two daemons plus three shell bridges, all of \
which modelled the same simulated server."
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

# Integration branch carrying the consolidated simulator (PR#4). Revert the
# branch to "main" once that merges; the recipe needs no other change.
SRC_URI = "git://git@bitbucket.sw.nxp.com/isp/bmc_mailbox.git;protocol=ssh;branch=integration/latu-dcm-plus-pr2 \
           file://mock-server.service \
"
SRCREV = "${AUTOREV}"
PV = "1.0+git${SRCPV}"

inherit systemd

# Start the simulator at boot. It used to be launched by hand, which meant the
# WebUI pages it feeds were empty on any board where someone had not remembered
# to start it - the failure looked like a bug in the event log rather than a
# missing process.
SYSTEMD_SERVICE:${PN} = "mock-server.service"
SYSTEMD_AUTO_ENABLE = "enable"

# The git fetcher clones the repo to ${UNPACKDIR}/${BP} (for example
# sources/mock-server-1.0+git), not the legacy ${UNPACKDIR}/git stub.
S = "${UNPACKDIR}/${BP}"

# sd-bus, used by sim_dbus.c to publish the host event log, POST codes and
# inventory. It lives in libsystemd, so the systemd recipe has to populate this
# recipe's sysroot with the header and library.
DEPENDS = "systemd"

# libsystemd is only built when systemd is the init manager, which is the case
# for OpenBMC images but is worth stating so the failure mode is a clear
# unsatisfied dependency rather than a missing header at compile time.
REQUIRED_DISTRO_FEATURES = "systemd"
inherit features_check

# mock_server.c includes the driver UAPI header shared via the relay ABI.
DRV_HEADER_DIR = "${S}/kernel_driver/imx9-qspi-mailbox"

# No configure step.
#
# The repo's top-level Makefile also builds the kernel module, so the inherited
# "make clean" recurses into kernel_driver/ and dies on "KERNEL_DIR is not set" -
# this recipe only builds the userspace daemon, and the module is packaged
# separately by qspi-mailbox. do_compile below invokes the compiler directly on
# the three app sources, so there is nothing to configure or pre-clean.
do_configure[noexec] = "1"

do_compile() {
    # -pthread: the daemon is multi-threaded by design (mailbox service loop,
    # driver boot handshake, alert dispatch, MCTP responder).
    # -lsystemd: sd-bus, for the D-Bus publication surface.
    ${CC} ${CFLAGS} ${LDFLAGS} -Wall -Wextra -O2 -pthread \
        -I${DRV_HEADER_DIR} \
        -o mock_server \
        ${S}/app/mock_server.c ${S}/app/sim_dbus.c ${S}/app/sim_mctp.c \
        -pthread -lsystemd
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 mock_server ${D}${bindir}/mock_server

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/mock-server.service ${D}${systemd_system_unitdir}/

    # Ship the operator guide next to the binary; the unit's Documentation=
    # line points at it.
    install -d ${D}${docdir}/mock_server
    install -m 0644 ${S}/app/MOCK_SERVER_USER_GUIDE.md ${D}${docdir}/mock_server/
    install -m 0644 ${S}/app/mock_server_alarm.example.txt ${D}${docdir}/mock_server/
    install -m 0644 ${S}/app/mock_server_values.example.txt ${D}${docdir}/mock_server/
}

FILES:${PN} += "${bindir}/mock_server \
                ${systemd_system_unitdir}/* \
                ${docdir}/mock_server/* \
"

# The D-Bus consumers mock_server publishes to. Without these on the image the
# simulator still serves the mailbox, but the WebUI pages it feeds stay empty:
#   phosphor-logging            - host SEL entries -> Redfish EventLog
#   phosphor-post-code-manager  - State.Boot.Raw   -> Redfish PostCodes
#   phosphor-inventory-manager  - Notify           -> Redfish hardware pages
RDEPENDS:${PN} += "phosphor-logging phosphor-post-code-manager phosphor-inventory-manager"
