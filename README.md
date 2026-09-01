# XGC2 Robot FS150

This repository stores real-vehicle resources for the FS150 aircraft used by
XGC2.  It is separate from the Gazebo/SITL package:

```text
products/robotics/fs150
  Real aircraft resources: onboard computer, PX4 export notes, wiring,
  runtime configuration, field-debug notes.

products/ros1/simulator/gazebo-sim/fs150-sitl
  ROS/Gazebo/PX4 SITL wrapper and simulation model.
```

The repository is intended for resources that are tied to the physical FS150
platform and should follow the aircraft across deployments.

## Package

- Product id: `xgc2-fs150`
- Source path: `products/robotics/fs150`
- Release branch: `main`
- Package type: mixed Debian profile package
- Published package:
  - `xgc2-fs150`
  - `xgc2-fs150-mavlink-router`

The `xgc2-fs150` package is a real-vehicle aggregation package.  It installs the FS150
resources under `/opt/xgc2/robots/fs150` and depends on the ROS Noetic,
MAVROS, VRPN, and MAVLink router packages expected on the onboard computer.
It does not depend on XGC2 Linux host-utils.

The `xgc2-fs150-mavlink-router` package is the opt-in flight-runtime router
unit.  It depends on the XGC2-published `xgc2-mavlink-router` binary
package and installs `/etc/xgc2/fs150-mavlink-router/router.conf` plus the
systemd units.  It does not enable or start any unit.

`pymavlink` is useful for low-level MAVLink debugging, but it is not available
as a standard Ubuntu Focal/ROS Noetic APT package in the checked repositories.
Install it separately for debug sessions if needed.

The `xgc2-fs150` package itself does not install, enable, or start FS150
flight-runtime systemd services.  Install `xgc2-fs150-mavlink-router` to
place the units on disk, then enable them yourself if this aircraft should
claim `/dev/ttyS7` at boot.

For a one-shot companion bring-up (Aliyun ubuntu-ports + ROS key repair +
XGC2 apt + quarantine foreign/broken apt lists + install router + stop/mask
legacy mavlink units + free `/dev/ttyS7` + enable router + HEARTBEAT gate +
Wi-Fi/static IPv4 **last**, never reconnect), run on the aircraft:

```bash
sudo bash onboard/scripts/install-mavlink-router.sh --yes \
  --lan-address 192.168.51.24
```

Field SSID/PSK are defaulted. Omit `--lan-address` on a TTY and the script
prompts only for this aircraft's IPv4. Default gateway/DNS is `192.168.51.1`
(`/24`; **`/32` is refused** — it is the known “powered on but SSH hangs
until someone pings” bug). Same-host prefix fixes are applied live without
`connection up`. `--skip-wifi` leaves addressing alone.

The script **fails** if no FC MAVLink appears on `127.0.0.1:14561` after the
companion is at **921600** (usual cause: PX4 still on 115200). Fix PX4 via QGC
wired serial, then re-run or restart the unit. Use `--skip-link-check` only when
you intentionally install before the FC baud is updated.

Packaged UART baud is **921600** (hard rule). Do not lower it for a quick
heartbeat. See `docs/mavlink_timesync_rtt.md`.

## Install

Configure both the ROS Noetic APT source and the XGC2 APT source first.  Then:

```bash
sudo apt update
sudo apt install xgc2-fs150
sudo apt install xgc2-fs150-mavlink-router
```

Smoke test:

```bash
test -d /opt/xgc2/robots/fs150/docs
test -f /opt/xgc2/robots/fs150/docs/rk356x_performance_mode.md
dpkg -s xgc2-fs150
dpkg -s xgc2-fs150-mavlink-router
! systemctl is-enabled xgc2-fs150-mavlink-router.service
test -f /lib/systemd/system/xgc2-fs150-camera.service
test -f /etc/xgc2/fs150-mavlink-router/router.conf
```

## Source Layout

```text
docs/                         Vehicle-level notes and debug records.
onboard/communication/        MAVLink router topology (not a ROS swarm bridge)
onboard/sensors/              Optional MIPI / rkisp camera workspace
onboard/autostart/            systemd: communication + camera
px4/                          Real PX4 firmware/parameter export notes.
```

There is no `onboard/base`. PX4 on the flight controller is the vehicle
base; this companion computer only routes MAVLink and optionally runs the
camera. `autostart` only installs the units. It does not enable
communication, camera, or Media Edge.

## MAVLink Router

The FS150 service package installs this static router topology:

- TCP server on `5760` for QGC active connections.
- UART `/dev/ttyS7` at `921600` baud for the PX4 flight controller.
- Remote MAVROS UDP server on `0.0.0.0:14560` with `BlockMsgIdOut = 105, 106, 331`.
- Local MAVROS UDP server on `127.0.0.1:14561` without message filtering.
  Onboard `fs150_mavros` / `xgc2-fs150-mavros.service` connects here
  (`udp://:14551@127.0.0.1:14561`). The unit is install-only.

The message block is applied only on the remote UDP endpoint output path, so
local MAVROS can still receive high-rate IMU data from message `105`.

## Current Notes

- RK356x/RK3566 onboard-computer CPU governor modes and performance-mode
  commands are documented in
  [docs/rk356x_performance_mode.md](docs/rk356x_performance_mode.md).
- Flight-controller UART routing and MAVROS/PX4 `TIMESYNC` RTT warning behavior
  are documented in
  [docs/mavlink_timesync_rtt.md](docs/mavlink_timesync_rtt.md).

## Repository Boundary

This repository owns:

- real FS150 onboard-computer runtime notes and configuration references;
- real PX4 parameter/firmware export notes;
- real-vehicle port, sensor, and field-test records;
- the `xgc2-fs150` real-vehicle aggregation Debian package.
- the `xgc2-fs150-mavlink-router` service Debian package.

This repository does not own:

- Gazebo SDF/URDF models;
- SITL launch files;
- controller source code;
- generated logs, rosbags, PX4 ULog files, or packet captures.

## License

Proprietary.  This repository is public for integration visibility, but it does
not grant redistribution or reuse rights beyond the project owner's intent.
