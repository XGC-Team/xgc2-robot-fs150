# FS150 communication

This is the MAVLink router, not a ROS swarm bridge.

Sibling of `onboard/sensors`. There is no `onboard/base`.

```text
mavlink-router/router.conf
mavlink-router/xgc2-fs150-mavlink-router.service
```

The router binary is APT `xgc2-mavlink-router` (`/usr/bin/mavlink-routerd`).
This tree only owns the FS150 topology:

- TCP `5760` for QGC
- UART `/dev/ttyS7` at `921600` to PX4
- remote MAVROS UDP `0.0.0.0:14560` with `BlockMsgIdOut = 105, 106, 331`
- local MAVROS UDP `127.0.0.1:14561` unfiltered

Install `xgc2-fs150-mavlink-router` to enable the unit. The aggregator
package `xgc2-fs150` does not start it.
