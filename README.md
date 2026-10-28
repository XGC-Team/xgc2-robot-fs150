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

Robot preparation uses the shared `XGC-Team/xgc2-tool-scripts` installer and
`fs150-focal-noetic` profile. This product no longer maintains a separate one-shot
installer or PX4 checker. Its onboard directory owns the product runtime, launch
files, service units and device configuration.

Use the published `onboard-baseline/bootstrap.sh` for third-party environment
preparation, then `robot-command.sh FS150 install-services` for the router product.
Service enable/start, network configuration/activation and PX4 parameter operations
are separate explicit tasks. Preparation does not write FC parameters or reboot it.

Packaged UART baud is **921600** (hard rule). Do not lower it for a quick
heartbeat. See `docs/mavlink_timesync_rtt.md`. Field RTT/TIMESYNC notes live
in `xgc2-dev-memory` `memory/now/fs150-uart-921600.md`.

## Install

After preparing the environment, use the shared explicit product installation entry:

```bash
set -o pipefail
curl -fsSL https://xgc2.xiaokang.ink/scripts/robot-command.sh | sudo bash -s -- \
  FS150 install-services --profile fs150-focal-noetic \
  --apt-url https://xgc2.apt.xiaokang.ink --yes
```

This installs the robot assets and router without enabling or starting services. Use the corresponding
`enable-services` or `start-services` task when selected by the operator.

Smoke test:

```bash
test -d /opt/xgc2/robots/fs150/docs
test -f /opt/xgc2/robots/fs150/docs/rk356x_performance_mode.md
dpkg -s xgc2-fs150
dpkg -s xgc2-fs150-mavlink-router
test -f /lib/systemd/system/xgc2-fs150-media-edge.service
test -f /etc/xgc2/fs150-mavlink-router/router.conf
```

## Source Layout

```text
docs/                         Onboard operator notes (present tense)
onboard/communication/        MAVLink router topology (not a ROS swarm bridge)
onboard/sensors/              Optional MIPI / rkisp camera: media roster
onboard/autostart/            systemd: communication, MAVROS, mocap, Media Edge
px4/                          Real PX4 firmware/parameter export notes.
```

There is no `onboard/base`. PX4 on the flight controller is the vehicle
base; this companion computer only routes MAVLink and optionally runs the
camera, through Media Edge. `autostart` only installs the units. It does not
enable communication, MAVROS, mocap, or Media Edge.

## MAVLink Router

The FS150 service package installs this static router topology:

- TCP server on `5760` for QGC active connections.
- UART `/dev/ttyS7` at `921600` baud for the PX4 flight controller.
- Remote MAVROS UDP server on `0.0.0.0:14560` with `BlockMsgIdOut = 105, 106, 331, 132`.
- Local MAVROS UDP server on `127.0.0.1:14561` without message filtering.
  Onboard `fs150_mavros` / `xgc2-fs150-mavros.service` connects here
  (`udp://:14551@127.0.0.1:14561`). Msgid 30/31/32 stay on the air at 15 Hz
  via flight-controller `extras.txt` (`configure linux`), not a rates unit.

The message block is applied only on the remote UDP endpoint output path, so
local MAVROS can still receive high-rate IMU data from message `105`.

## Operator notes

- CPU governor for high-rate tests: [docs/rk356x_performance_mode.md](docs/rk356x_performance_mode.md)
- UART 921600 / TIMESYNC: [docs/mavlink_timesync_rtt.md](docs/mavlink_timesync_rtt.md)

Field debug belongs in `xgc2-dev-memory` (`memory/field/fs150/`).

## Repository Boundary

This repository owns:

- real FS150 onboard-computer configuration;
- PX4 parameter/firmware export notes;
- the `xgc2-fs150` and `xgc2-fs150-mavlink-router` Debian packages.

Field debug and survey notes are not this repository; they live in
`xgc2-dev-memory` `memory/field/fs150/`.

This repository does not own:

- Gazebo SDF/URDF models;
- SITL launch files;
- controller source code;
- generated logs, rosbags, PX4 ULog files, or packet captures.

## License

Proprietary.  This repository is public for integration visibility, but it does
not grant redistribution or reuse rights beyond the project owner's intent.
