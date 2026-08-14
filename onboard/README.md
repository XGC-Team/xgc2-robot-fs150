# FS150 onboard

Sibling trees. There is no separate `base/` — the airframe brain is PX4
on the flight controller, not a chassis stack on this companion computer.

```text
communication/           MAVLink router (YAML + systemd)
                         binary comes from APT xgc2-mavlink-router

sensors/src/             optional MIPI camera workspace
  camera_ros             V4L2 / rkisp publisher (field driver)
  fs150_onboard_sensors  compose launch
```

systemd for the router lives in `communication/mavlink-router` and is
shipped by `xgc2-fs150-mavlink-router`. The camera is not enabled at boot.
