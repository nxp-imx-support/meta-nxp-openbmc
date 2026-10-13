FILESEXTRAPATHS:prepend:frdm-imx91 := "${THISDIR}/${PN}:"

EXTRA_OEMESON:append:frdm-imx91 = " -Dnegative-errno-on-fail=true"


CHIPS = " \
       i2c@426b0000/sensor@48 \
       "

ITEMSFMT = "soc@0/bus@42000000/{0}.conf"

ITEMS = "${@compose_list(d, 'ITEMSFMT', 'CHIPS')}"


ENVS = "obmc/hwmon/{0}"
SYSTEMD_ENVIRONMENT_FILE:${PN}:append:frdm-imx91 = " ${@compose_list(d, 'ENVS', 'ITEMS')}"
