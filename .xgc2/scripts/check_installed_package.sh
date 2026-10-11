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
test ! -e /opt/xgc2/robots/fs150/onboard/sensors/src/xgc_camera_media
test ! -e /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/launch
test -f /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/config/media-sources.json
grep -q '"kind": "pipeline"' /opt/xgc2/robots/fs150/onboard/sensors/src/fs150_onboard_sensors/config/media-sources.json
! grep -rq 'xgc_native_v4l2_rtp\|xgc_ros_image_rtp\|native_v4l2_media' /opt/xgc2/robots/fs150/onboard
test -f /opt/xgc2/robots/fs150/onboard/sensors/legacy/README.md
test -f /opt/xgc2/robots/fs150/onboard/autostart/README.md
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavlink-router.service
test ! -e /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavlink-rates.service
test ! -e /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-camera.service
test ! -e /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-camera
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-media-edge.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mavros.service
test -f /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/systemd/xgc2-fs150-mocap.service
test -f /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mavros/launch/mavros.launch
test -f /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/launch/mocap.launch
test ! -e /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/scripts/vrpn_relay
test ! -e /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/launch/vrpn.launch
grep -q 'xgc2_vrpn_relay' /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/launch/mocap.launch
grep -q 'FS150_01' /opt/xgc2/robots/fs150/onboard/communication/src/fs150_mocap/launch/mocap.launch
test -x /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/start-communication
test ! -e /opt/xgc2/robots/fs150/onboard/autostart/src/fs150_onboard_autostart/scripts/set-mavlink-rates
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
test ! -e /usr/lib/xgc2/fs150/autostart/set-mavlink-rates
test -x /usr/lib/xgc2/fs150/autostart/start-mavros
test -x /usr/lib/xgc2/fs150/autostart/start-mocap
test ! -e /usr/lib/xgc2/fs150/autostart/start-camera
test -x /usr/lib/xgc2/fs150/autostart/start-media-edge
test ! -e /usr/lib/xgc2/fs150/check-px4-params.py
test ! -e /usr/lib/xgc2/fs150/check-px4-params.sh
test ! -e /usr/share/xgc2/fs150/expected-px4-params.json
test -f /lib/systemd/system/xgc2-fs150-mavlink-router.service
test ! -e /lib/systemd/system/xgc2-fs150-mavlink-rates.service
test -f /lib/systemd/system/xgc2-fs150-mavros.service
test -f /lib/systemd/system/xgc2-fs150-mocap.service
test ! -e /lib/systemd/system/xgc2-fs150-camera.service
test -f /lib/systemd/system/xgc2-fs150-media-edge.service
grep -q '^RuntimeDirectoryMode=0700$' /lib/systemd/system/xgc2-fs150-media-edge.service
grep -q -- '--rpc-socket' /usr/lib/xgc2/fs150/autostart/start-media-edge
test -f /usr/share/xgc2/fs150/mavros/launch/mavros.launch
test -f /usr/share/xgc2/fs150/mocap/launch/mocap.launch
test ! -e /usr/share/xgc2/fs150/mocap/vrpn_relay
test ! -e /usr/share/xgc2/fs150/mocap/launch/vrpn.launch
grep -q '127.0.0.1:14561' /usr/share/xgc2/fs150/mavros/launch/mavros.launch
grep -q 'xgc2_vrpn_relay' /usr/share/xgc2/fs150/mocap/launch/mocap.launch
grep -q 'FS150_01' /usr/share/xgc2/fs150/mocap/launch/mocap.launch
grep -q '^Device = /dev/ttyS7$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^Baud = 921600$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^BlockMsgIdOut = 105, 106, 331, 132$' /etc/xgc2/fs150-mavlink-router/router.conf
! grep -q 'xgc2-fs150-mavlink-rates' /lib/systemd/system/xgc2-fs150-mavlink-router.service
test -f /etc/apt/preferences.d/xgc2-fs150-retract-20

if command -v systemctl >/dev/null 2>&1; then
  for unit in \
    xgc2-fs150-mavlink-router.service \
    xgc2-fs150-mavros.service \
    xgc2-fs150-mocap.service \
    xgc2-fs150-media-edge.service
  do
    if systemctl is-enabled "${unit}" >/dev/null 2>&1; then
      echo "${unit} must not be enabled on install" >&2
      exit 1
    fi
  done
fi

echo "Installed FS150 robot package check passed"
