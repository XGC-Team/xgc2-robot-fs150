# FS150 autostart

Owns every onboard systemd unit. Sibling of `communication` and `sensors`.
There is no `base/` — communication (MAVLink router) is the min-boot unit.

```text
src/fs150_onboard_autostart
  systemd/xgc2-fs150-mavlink-router.service   communication
  systemd/xgc2-fs150-camera.service           native V4L2 + H264
  systemd/xgc2-fs150-media-edge.service       WebRTC
  scripts/start-communication
  scripts/start-camera
  scripts/start-media-edge
  scripts/wait-device
```

The router package enables communication only. Camera and Media Edge are
installed, never enabled, never started.
