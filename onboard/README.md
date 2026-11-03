# FS150 onboard

Sibling trees. There is no separate `base/` — the airframe brain is PX4
on the flight controller, not a chassis stack on this companion computer.

```text
communication/           MAVLink router topology (router.conf)
                         + official mavros/px4.launch (127.0.0.1:14561)
                         binary comes from APT xgc2-mavlink-router

sensors/src/             optional MIPI camera assembly
  fs150_onboard_sensors  media-sources.json: the camera is a
                         Media Edge pipeline source

autostart/src/           fs150_onboard_autostart
                         communication + MAVROS diagnostic + Media Edge
                         systemd (install only; no unit is boot-enabled)
```

Functional trees do not ship systemd. Units live in `autostart`.

Core/Agent starts VRPN and the PX4 adapter; the adapter supplies vision_pose.
