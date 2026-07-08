SUMMARY = "DPU DRM Atomic Scaler App"
DESCRIPTION = "Atomic DRM modeset + scaling test application"
LICENSE = "CLOSED"

SRC_URI = "file://dpu_pci_scan.c \
           file://dpu-drm-app.service"

S = "${UNPACKDIR}"

DEPENDS = "libdrm"

inherit pkgconfig systemd

SYSTEMD_SERVICE:${PN} = "dpu-drm-app.service"
SYSTEMD_AUTO_ENABLE = "enable"

INSANE_SKIP:${PN}-dbg += "buildpaths"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${UNPACKDIR}/dpu_pci_scan.c -o dpu_pci_scan \
        $(pkg-config --cflags --libs libdrm)
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 dpu_pci_scan ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/dpu-drm-app.service \
        ${D}${systemd_system_unitdir}/
}