SRCREV = "af1b2b438faccba5c7cef52f8f4325e6f2ef3027"

# redfish-dump-log is enabled alongside it so the BMC dump entries created by
# xyz.openbmc_project.Dump.Manager (already running on this image) are
# reachable too, which is what the WebUI expects when offering a dump
# download next to the event log.
PACKAGECONFIG:append = " redfish-dbus-log redfish-dump-log"

