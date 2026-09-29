#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright 2025-2026 NXP
#
# poweron.sh - power the host on
#
# Releases the host from reset / S5 and reports Running only once the host is
# actually observed to be up (or the wait times out). The previous version
# asserted "Running" a second after toggling the GPIO regardless of whether the
# host had come up.

. /usr/sbin/nxp_host_power.sh

host_power_on

exit 0
