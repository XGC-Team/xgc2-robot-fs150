# FS150 onboard

Sibling trees. There is no separate `base/` — the airframe brain is PX4
on the flight controller, not a chassis stack on this companion computer.

```text
communication/           MAVLink router topology (router.conf)
                         + fs150_mavros launch (127.0.0.1:14561)
                         + fs150_mocap (tracker + vision_pose assembly)
                         binary comes from APT xgc2-mavlink-router

sensors/src/             optional MIPI camera assembly
  fs150_onboard_sensors  compose launch + media-sources.json
                         (capture is shared xgc2_camera_driver)

autostart/src/           fs150_onboard_autostart
                         communication + MAVROS + camera + Media Edge
                         systemd (install only; no unit is boot-enabled)
```

Functional trees do not ship systemd. Units live in `autostart`.
