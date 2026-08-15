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
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/xgc_camera_media/xgc_native_v4l2_rtp
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/launch/camera.launch
test -f /opt/xgc2/robots/fs150/onboard/sensors/legacy/README.md
test -f /opt/xgc2/robots/fs150/onboard/autostart/README.md
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavlink-router.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-camera.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-media-edge.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavros.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mocap.service
test -f /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mavros/launch/mavros.launch
test -f /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/launch/mocap.launch
test -x /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/scripts/vrpn_relay
test -x /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-communication
test -x /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-mavros
test -x /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-mocap
test ! -e /opt/xgc2/robots/fs150/onboard/mavlink-router
test ! -e /opt/xgc2/robots/fs150/onboard/base
test -f /opt/xgc2/robots/fs150/px4/README.md

dpkg -s xgc2-fs150-mavlink-router >/dev/null
test -f /etc/xgc2/fs150-mavlink-router/router.conf
test -d /etc/xgc2/fs150-mavlink-router/config.d
test -f /etc/xgc2/fs150/onboard.env
test -x /usr/lib/xgc2/fs150/autostart/start-communication
test -x /usr/lib/xgc2/fs150/autostart/start-mavros
test -x /usr/lib/xgc2/fs150/autostart/start-mocap
test -x /usr/lib/xgc2/fs150/autostart/start-camera
test -f /lib/systemd/system/xgc2-fs150-mavlink-router.service
test -f /lib/systemd/system/xgc2-fs150-mavros.service
test -f /lib/systemd/system/xgc2-fs150-mocap.service
test -f /lib/systemd/system/xgc2-fs150-camera.service
test -f /usr/share/xgc2/fs150/mavros/launch/mavros.launch
test -f /usr/share/xgc2/fs150/mocap/launch/mocap.launch
grep -q '127.0.0.1:14561' /usr/share/xgc2/fs150/mavros/launch/mavros.launch
grep -q 'FS150_01' /usr/share/xgc2/fs150/mocap/launch/vrpn.launch
grep -q '^Device = /dev/ttyS7$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^Baud = 921600$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^BlockMsgIdOut = 105, 106, 331$' /etc/xgc2/fs150-mavlink-router/router.conf

if command -v systemctl >/dev/null 2>&1; then
  for unit in \
    xgc2-fs150-mavlink-router.service \
    xgc2-fs150-mavros.service \
    xgc2-fs150-mocap.service \
    xgc2-fs150-camera.service \
    xgc2-fs150-media-edge.service
  do
    if systemctl is-enabled "${unit}" >/dev/null 2>&1; then
      echo "${unit} must not be enabled on install" >&2
      exit 1
    fi
  done
fi

echo "Installed FS150 robot package check passed"
