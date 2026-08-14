#!/usr/bin/env bash
set -euo pipefail

dpkg -s xgc2-fs150 >/dev/null
test -d /opt/xgc2/robots/fs150/docs
test -f /opt/xgc2/robots/fs150/README.md
test -f /opt/xgc2/robots/fs150/docs/rk356x_performance_mode.md
test -f /opt/xgc2/robots/fs150/onboard/README.md
test -f /opt/xgc2/robots/fs150/onboard/communication/README.md
test -f /opt/xgc2/robots/fs150/onboard/communication/mavlink-router/router.conf
test ! -e /opt/xgc2/robots/fs150/onboard/communication/mavlink-router/xgc2-fs150-mavlink-router.service
test -f /opt/xgc2/robots/fs150/onboard/sensors/README.md
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/camera_ros/package.xml
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/launch/camera.launch
test -f /opt/xgc2/robots/fs150/onboard/autostart/README.md
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavlink-router.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-camera.service
test -x /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-communication
test ! -e /opt/xgc2/robots/fs150/onboard/mavlink-router
test ! -e /opt/xgc2/robots/fs150/onboard/base
test -f /opt/xgc2/robots/fs150/px4/README.md

dpkg -s xgc2-fs150-mavlink-router >/dev/null
test -f /etc/xgc2/fs150-mavlink-router/router.conf
test -d /etc/xgc2/fs150-mavlink-router/config.d
test -f /etc/xgc2/fs150/onboard.env
test -x /usr/lib/xgc2/fs150/autostart/start-communication
test -x /usr/lib/xgc2/fs150/autostart/start-camera
test -f /lib/systemd/system/xgc2-fs150-mavlink-router.service
test -f /lib/systemd/system/xgc2-fs150-camera.service
grep -q '^Device = /dev/ttyS7$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^Baud = 921600$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^BlockMsgIdOut = 105, 106, 331$' /etc/xgc2/fs150-mavlink-router/router.conf

if command -v systemctl >/dev/null 2>&1; then
  systemctl is-enabled xgc2-fs150-mavlink-router.service >/dev/null
  if systemctl is-enabled xgc2-fs150-camera.service >/dev/null 2>&1; then
    echo "camera unit must not be enabled" >&2
    exit 1
  fi
fi

echo "Installed FS150 robot package check passed"
