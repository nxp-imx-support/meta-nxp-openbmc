SUMMARY = "OBMF BMC validation and demo applications"
DESCRIPTION = "Userspace validation and demo applications for the OBMF ICP-over-USB BMC driver."
 
LICENSE = "Apache-2.0"
 
SRC_URI = "git://git@bitbucket.sw.nxp.com/~nxa15309/ioe_obmf_linux.git;protocol=ssh;branch=main"
SRCREV = "${AUTOREV}"
 
PV = "1.0+git${SRCPV}"
 
S = "${UNPACKDIR}/${BP}/bmc_apps"
 
LIC_FILES_CHKSUM = "file://${UNPACKDIR}/${BP}/LICENSE;md5=a9beb3c8e496fe09d182543be7a114b5"
 
do_compile() {
oe_runmake CC="${CC}" all
}
 
do_install() {
	install -d ${D}${bindir}
 
	for f in ${S}/obmf_*; do
		if [ -f "$f" ] && [ -x "$f" ]; then
			install -m 0755 "$f" ${D}${bindir}/
		fi
	done
}
FILES:${PN} += "${bindir}/*"
 
