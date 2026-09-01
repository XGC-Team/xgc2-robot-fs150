# FS150 communication

This is the MAVLink router, not a ROS swarm bridge.

Sibling of `onboard/sensors` and `onboard/autostart`. There is no
`onboard/base`. systemd lives in `autostart`, not here.

```text
mavlink-router/router.conf
expected-px4-params.json                 snapshot of DEFAULT_EXPECTED (not packaged)
src/fs150_mavros/launch/mavros.launch
src/fs150_mocap/launch/mocap.launch      assembly: tracker + vision_pose
```

Onboard checker (no MAVROS): `onboard/scripts/check-px4-params.py` against
router UDP `127.0.0.1:14561`. The expected table is builtin
(`DEFAULT_EXPECTED`: TELEM1/921600, EKF2 vision, arm without GPS,
kill/land disarm, 3S). The operator path is the XGC2 User script
`FS150 · check PX4 params` (full file embedded; no companion copy).
Optional `--expected` JSON overrides the builtin table.

The router binary is APT `xgc2-mavlink-router` (`/usr/bin/mavlink-routerd`).
This tree only owns the FS150 topology:

- TCP `5760` for QGC
- UART `/dev/ttyS7` at `921600` to PX4
- remote / GCS UDP `0.0.0.0:14560` with `BlockMsgIdOut = 105, 106, 331`
- loopback UDP `127.0.0.1:14561` unfiltered — onboard MAVROS and local
  probes only (param checker). Do not aim ground tools at 14561.

Onboard MAVROS is `fs150_mavros`. It only passes arguments to official
`mavros/px4.launch` and talks to the local router port:

```text
udp://:14551@127.0.0.1:14561
```

`14560` stays the filtered remote/GCS MAVROS endpoint. Do not point the
onboard wrapper at `14560`.

```bash
roslaunch fs150_mavros mavros.launch
# or
sudo systemctl start xgc2-fs150-mavros.service
```

Each aircraft also runs its own VRPN client against **one** Motive
tracker (`FS150_01` by default). `fs150_mocap` only names that tracker
and turns vision_pose on. The client, quality gate, and 30 Hz drop
policy live in APT `xgc2-vrpn-relay` (`xgc2_vrpn_relay`).

```bash
sudo systemctl start xgc2-fs150-mocap.service
```

Install `xgc2-fs150-mavlink-router` to install the communication,
MAVROS, and mocap units owned by `onboard/autostart`. The package does
not enable or start them. The aggregator package `xgc2-fs150` also does
not start them.
