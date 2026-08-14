#!/usr/bin/env bash
set -euo pipefail

dpkg -s xgc2-fs150 >/dev/null
test -d /opt/xgc2/robots/fs150/docs
test -f /opt/xgc2/robots/fs150/README.md
test -f /opt/xgc2/robots/fs150/docs/rk356x_performance_mode.md
test -f /opt/xgc2/robots/fs150/onboard/README.md
test -f /opt/xgc2/robots/fs150/onboard/communication/README.md
test -f /opt/xgc2/robots/fs150/onboard/communication/mavlink-router/router.conf
test -f /opt/xgc2/robots/fs150/onboard/sensors/README.md
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/camera_ros/package.xml
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/launch/camera.launch
test ! -e /opt/xgc2/robots/fs150/onboard/mavlink-router
test ! -e /opt/xgc2/robots/fs150/onboard/base
test -f /opt/xgc2/robots/fs150/px4/README.md

dpkg -s xgc2-fs150-mavlink-router >/dev/null
test -f /etc/xgc2/fs150-mavlink-router/router.conf
test -d /etc/xgc2/fs150-mavlink-router/config.d
test -f /lib/systemd/system/xgc2-fs150-mavlink-router.service
grep -q '^Device = /dev/ttyS7$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^Baud = 921600$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^BlockMsgIdOut = 105, 106, 331$' /etc/xgc2/fs150-mavlink-router/router.conf

if command -v systemctl >/dev/null 2>&1; then
  systemctl is-enabled xgc2-fs150-mavlink-router.service >/dev/null
fi

echo "Installed FS150 robot package check passed"
