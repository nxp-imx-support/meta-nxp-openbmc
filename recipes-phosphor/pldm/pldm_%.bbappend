FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGECONFIG:append = " transport-af-mctp"

SRC_URI:append = " file://host_eid"

do_install:append() {
    install -D -m 0644 ${UNPACKDIR}/host_eid ${D}/usr/share/pldm
}
