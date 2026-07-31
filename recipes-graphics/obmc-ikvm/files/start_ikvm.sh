#!/bin/sh
# Copyright 2025-2026 NXP
# start_ikvm.sh - Configure and start iKVM functionality for i.MX boards

modprobe stream2v4l2
systemctl daemon-reload
sleep 1
systemctl restart obmc-ikvm
systemctl status obmc-ikvm
