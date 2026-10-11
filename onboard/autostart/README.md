# FS150 autostart

Owns every onboard systemd unit. Sibling of `communication` and `sensors`.
There is no `base/` — communication (MAVLink router) is the min-boot unit.

```text
src/fs150_onboard_autostart
  systemd/xgc2-fs150-mavlink-router.service   communication
  systemd/xgc2-fs150-mavros.service           MAVROS -> 127.0.0.1:14561
  systemd/xgc2-fs150-mocap.service            assembly of xgc2_vrpn_relay
  systemd/xgc2-fs150-media-edge.service       WebRTC; the camera is its pipeline source
  scripts/start-communication
  scripts/start-mavros
  scripts/start-mocap
  scripts/start-media-edge
  scripts/wait-device
```

The router package installs the units only. Communication, MAVROS, mocap,
and Media Edge are never enabled and never started by the package.
Msgid 30/31/32 stay at 15 Hz in flight-controller `extras.txt`
(`configure linux`). There is no rates systemd helper.
