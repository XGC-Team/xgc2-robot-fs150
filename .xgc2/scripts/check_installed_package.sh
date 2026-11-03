#!/usr/bin/env bash
set -euo pipefail
dpkg -s xgc2-fs150-mavlink-router >/dev/null
test -f /etc/xgc2/fs150-mavlink-router/router.conf
test -f /etc/xgc2/fs150/onboard.env
test -x /usr/lib/xgc2/fs150/autostart/wait-device
test -x /usr/lib/xgc2/fs150/autostart/start-communication
test -f /lib/systemd/system/xgc2-fs150-mavlink-router.service
grep -q '^Device = /dev/ttyS7$' /etc/xgc2/fs150-mavlink-router/router.conf
grep -q '^Baud = 921600$' /etc/xgc2/fs150-mavlink-router/router.conf
if dpkg -L xgc2-fs150-mavlink-router | grep -E 'mavros|mocap|media-edge|/opt/xgc2/robots'; then
  echo 'Router package must contain only router runtime files' >&2
  exit 1
fi
! grep -Eq 'MAV_SYS_ID|MOCAP_RIGID_BODY|VRPN_' /etc/xgc2/fs150/onboard.env
! systemctl is-enabled xgc2-fs150-mavlink-router.service >/dev/null 2>&1
echo 'Installed FS150 router-only package check passed'
