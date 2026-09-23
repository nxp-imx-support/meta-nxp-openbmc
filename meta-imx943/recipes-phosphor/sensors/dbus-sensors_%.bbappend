# Sensor daemons for the FPGA mailbox topology.
#
#   hwmontempsensor - TMP75 / P3T1755 / PCT2075 on the virtual I2C and I3C
#                     buses, plus the FPGA-internal die temperature bound by
#                     hwmon name (Type "HwmonTemp" in the Entity Manager JSON).
#   fansensor       - MAX31790 fan controllers (tach + PWM).
#   adcsensor       - ADC121C021 ADC channels.
#   psusensor       - PMBus regulators and power monitors: LT7182S, BMR350,
#                     LTC4287 and INA226. Without this the voltage, current and
#                     power rails in the chassis JSON never reach D-Bus, so they
#                     are absent from Redfish and from IPMI SDRs.
PACKAGECONFIG = " \
    hwmontempsensor \
    fansensor \
    adcsensor \
    psusensor \
    "
