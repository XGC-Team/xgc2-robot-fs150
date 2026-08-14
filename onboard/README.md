# FS150 onboard

Sibling trees. There is no separate `base/` — the airframe brain is PX4
on the flight controller, not a chassis stack on this companion computer.

```text
communication/           MAVLink router topology (router.conf)
                         binary comes from APT xgc2-mavlink-router

sensors/src/             optional MIPI camera workspace
  camera_ros             V4L2 / rkisp publisher (field driver)
  fs150_onboard_sensors  compose launch

autostart/src/           fs150_onboard_autostart
                         communication + camera systemd (install only
                         except communication is boot-enabled)
```

Functional trees do not ship systemd. Units live in `autostart`.
