FILESEXTRAPATHS:prepend:evb-imx93 := "${THISDIR}/${PN}:"

EXTRA_OEMESON:append:evb-imx93 = " -Dnegative-errno-on-fail=true"


CHIPS = " \
       i2c@426b0000/sensor@48 \
       "

ITEMSFMT = "soc@0/bus@42000000/{0}.conf"

ITEMS = "${@compose_list(d, 'ITEMSFMT', 'CHIPS')}"


ENVS = "obmc/hwmon/{0}"
SYSTEMD_ENVIRONMENT_FILE:${PN}:append:evb-imx93 = " ${@compose_list(d, 'ENVS', 'ITEMS')}"
