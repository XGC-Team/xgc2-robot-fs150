# FS150 autostart

Owns every onboard systemd unit. Sibling of `communication` and `sensors`.
There is no `base/` — communication (MAVLink router) is the min-boot unit.

```text
src/fs150_onboard_autostart
  systemd/xgc2-fs150-mavlink-router.service   communication
  systemd/xgc2-fs150-camera.service           camera
  scripts/start-communication
  scripts/start-camera
  scripts/wait-device
```

`xgc2-fs150-mavlink-router` installs both units, enables communication
for the next boot, and does not enable or start the camera.
