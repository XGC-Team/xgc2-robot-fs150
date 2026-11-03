# FS150 communication

This is the MAVLink router, not a ROS swarm bridge.

Sibling of `onboard/sensors` and `onboard/autostart`. There is no
`onboard/base`. systemd lives in `autostart`, not here.

```text
mavlink-router/router.conf
expected-px4-params.json                 snapshot of DEFAULT_EXPECTED (not packaged)
```

The canonical checker (no MAVROS) is maintained in tool-scripts under
`public/robot-commands/FS150/check-px4-params.py`, against router UDP
`127.0.0.1:14561`. The expected table is builtin (`DEFAULT_EXPECTED`).
The XGC2 User script calls the published `robot-command.sh FS150 check-px4-params`
entry; this product does not maintain a second implementation.
Optional `--expected` JSON overrides the builtin table.

The router binary is APT `xgc2-mavlink-router` (`/usr/bin/mavlink-routerd`).
This tree only owns the FS150 topology:

- TCP `5760` for QGC
- UART `/dev/ttyS7` at `921600` to PX4
- remote / GCS UDP `0.0.0.0:14560` with `BlockMsgIdOut = 105, 106, 331, 132`
- loopback UDP `127.0.0.1:14561` unfiltered — onboard MAVROS and local
  probes. Do not aim ground tools at 14561. Messages 30/31/32 have independently selected source rates in FC `extras.txt`.
  Remote-only reduction uses that router output's `MessageRatesOut` (router >= 3.0.0-14), preserving local source rates.

Onboard MAVROS is started by `start-mavros`, which calls the official
`mavros/px4.launch` directly. There is no FS150 forwarding launch.
It loads ROS, reads the actual FC heartbeat and MAV_SYS_ID via the local Router,
and compares it with the management-IP expectation before starting MAVROS.
The local URL is `udp://:14551@127.0.0.1:14561`; `gcs_url` is empty so Router
alone owns ground-station forwarding. Installation provides files only;
manual start and boot enable are separate choices.

```sh
sudo systemctl start xgc2-fs150-mavros.service
```

The official `vrpn_client_ros` package is installed for Core/Agent to start
against the selected rigid body. The PX4 robot adapter owns world-frame
projection and publishes vision_pose. FS150 does not install or start an
independent `xgc2_vrpn_relay` process.

The full `xgc2-fs150` package installs runtime resources; the separate
`xgc2-fs150-mavlink-router` package owns only Router configuration and its unit.
Neither package enables or starts flight-runtime services. Core/Agent owns
MAVROS and VRPN execution; the MAVROS unit is only a manual diagnostic helper.

Onboard MAVROS has no GCS forwarding argument. Its included MAVROS launch
receives an explicit empty `gcs_url`; QGC connects through the existing router
TCP 5760 entry. Do not add a broadcast URL or a second forwarding process.
The user reported a historical broadcast storm from such a MAVROS broadcast
configuration. Check this boundary with `python3 tests/check_onboard_mavros_topology.py`
from the product root.
