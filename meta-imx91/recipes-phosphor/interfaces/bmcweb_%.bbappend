# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 NXP
#
# Enable the D-Bus-backed Redfish event log in bmcweb.
#
# Why this is needed
# ------------------
# The upstream bmcweb PACKAGECONFIG default (meta-phosphor bmcweb_git.bb) is:
#
#     http-zstd kvm mutual-tls-auth redfish-allow-rotational-fans
#     redfish-bmc-journal redfish-oem-manager-fan-data vm-websocket
#
# Note what is absent: redfish-dbus-log. Without it bmcweb builds the SYSTEM
# event log (/redfish/v1/Systems/system/LogServices/EventLog/Entries) against
# the file backend, which reads /var/log/redfish - a file that only exists if
# something is configured to write Redfish-formatted records into it. Nothing
# on this image does, so the collection is permanently empty:
#
#     "Members": [], "Members@odata.count": 0
#
# and the WebUI "Event Logs" page renders blank even though
# phosphor-logging holds hundreds of entries on D-Bus. (redfish-bmc-journal
# only affects the separate BMC Journal log service under
# /redfish/v1/Managers/bmc/LogServices/Journal, which does work.)
#
# The FPGA SEL bridge in this layer (fpga-sel-bridge) already raises real
# phosphor-logging entries for every simulated host SEL record via
# xyz.openbmc_project.Logging.Create. Enabling redfish-dbus-log points
# bmcweb's EventLog at exactly that D-Bus data, so those entries surface in
# Redfish and the WebUI with no change to the bridge.
#
# redfish-dump-log is enabled alongside it so the BMC dump entries created by
# xyz.openbmc_project.Dump.Manager (already running on this image) are
# reachable too, which is what the WebUI expects when offering a dump
# download next to the event log.
PACKAGECONFIG:append = " redfish-dbus-log redfish-dump-log"
