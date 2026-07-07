# Enable temperature, fan and ADC sensors for all NXP iMX9x platforms
PACKAGECONFIG:append:pn-dbus-sensors:nxp = " hwmontempsensor fansensor adcsensor"
