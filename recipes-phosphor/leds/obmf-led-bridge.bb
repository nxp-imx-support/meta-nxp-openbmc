SUMMARY = "OBMF identify LED group to gpiochip bridge"
DESCRIPTION = "Mirrors the enclosure_identify LED group Asserted property onto \
the OBMF virtual gpiochip line (led0). The line is not a /sys/class/leds \
device, so phosphor-led-sysfs cannot drive it; this service bridges the D-Bus \
LED group (driven by the WebUI identify toggle and the id-button service) to \
the OBMF gpiochip using gpioset."
PR = "r1"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

inherit obmc-phosphor-systemd

# libgpiod provides gpioset/gpioinfo; phosphor-led-manager owns the group.
RDEPENDS:${PN} += "libgpiod-tools"

S = "${UNPACKDIR}"
SRC_URI += " \
    file://obmf-led-bridge.sh \
    file://obmf-led-bridge.service \
"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/obmf-led-bridge.sh ${D}${bindir}/obmf-led-bridge.sh
}

SYSTEMD_SERVICE:${PN} += "obmf-led-bridge.service"
