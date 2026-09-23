FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# The phosphor-led-manager binary shipped in this image is the JSON-config
# variant: at start it looks for a file named led-group-config.json under
# /etc/phosphor-led-manager then /usr/share/phosphor-led-manager, and the
# GroupManager systemd unit runs it with no -c argument (Type=dbus,
# BusName=xyz.openbmc_project.LED.GroupManager). Without that JSON file the
# daemon defines no LED groups, never claims the bus name, and systemd times
# it out and kills it. The result is that the enclosure_identify group never
# appears on D-Bus, so the WebUI identify toggle fails with
# "Cannot read properties of undefined (reading 'ServiceEnabled')" and the
# obmf-led-bridge service (which mirrors that group onto the OBMF gpiochip
# line) stays inactive waiting for a GroupManager that never activates.
#
# The imx-led-manager-config-native recipe only provides the OLD build-time
# led.yaml mechanism via virtual/phosphor-led-manager-config-native, which
# this JSON-config build does not consume at runtime. Ship the runtime JSON
# config here so the group is created on boot.

SRC_URI += "file://led-group-config.json"

do_install:append() {
    install -d ${D}${datadir}/phosphor-led-manager
    install -m 0644 ${UNPACKDIR}/led-group-config.json \
        ${D}${datadir}/phosphor-led-manager/led-group-config.json
}

FILES:${PN} += "${datadir}/phosphor-led-manager/led-group-config.json"
