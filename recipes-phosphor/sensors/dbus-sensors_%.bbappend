# Enable temperature, fan, ADC and PSU/PMBus sensors for all NXP iMX9x platforms.
# psusensor covers the PMBus regulators and power monitors behind the FPGA
# mailbox (LT7182S, BMR350, LTC4287, INA226).
PACKAGECONFIG:append:pn-dbus-sensors:nxp = " hwmontempsensor fansensor adcsensor psusensor"
