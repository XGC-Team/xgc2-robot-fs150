# FS150 MAVLink Timesync RTT Notes

This note records the FS150 flight-controller link observed on the RK356x
onboard computer and explains how MAVROS/PX4 compute the `TIMESYNC` round-trip
time warning.

## Observed Link

The current FS150 onboard computer exposes the flight controller through the
RK356x onboard UART, not through a USB ACM device:

```text
PX4 flight controller <-> RK356x serial7 <-> /dev/ttyS7 <-> mavlink-routerd
```

The observed Linux device is:

```text
/dev/ttyS7
/sys/devices/platform/fe6b0000.serial
driver: dw-apb-uart
device-tree alias: serial7
```

The active serial line setting was:

```text
921600 baud, 8N1, no hardware flow control
```

The running vehicle still used the legacy service:

```text
fs150-mavlink-router.service
ExecStart=/etc/init.d/fs150-mavlink-router.sh
```

The script starts:

```bash
sudo chmod 777 /dev/ttyS7
sudo ~/mavlink-routerd-glibc-aarch64-v4 -c /etc/init.d/fs150-mavlink-router.conf
```

The active legacy router configuration was:

```ini
[General]
TcpServerPort = 5760
MavlinkDialect = common

[UartEndpoint uart0]
Device = /dev/ttyS7
Baud = 921600
BlockMsgIdIn = 106, 331
BlockMsgIdOut = 106, 331

[UdpEndpoint udp0]
Mode = Server
Address = 0.0.0.0
Port = 14560
```

The process listened on:

```text
UDP 0.0.0.0:14560
TCP *:5760
```

This differs from the packaged `xgc2-fs150-mavlink-router` topology, which
uses `/etc/xgc2/fs150-mavlink-router/router.conf` and includes a local
`127.0.0.1:14561` MAVROS endpoint. Check the active service before comparing
field logs against package defaults.

## MAVROS TIMESYNC Flow

The MAVROS warning:

```text
TM : RTT too high for timesync: <value> ms.
```

is emitted by MAVROS, not by the application controller. It measures the
round-trip time of MAVLink `TIMESYNC` messages, not the latency of a control
setpoint topic.

With the default PX4 MAVROS config, MAVROS sends `TIMESYNC` at 10 Hz:

```yaml
conn:
  timesync_rate: 10.0
time:
  timesync_mode: MAVLINK
```

For each MAVROS-originated sample:

```text
MAVROS sends:
  tc1 = 0
  ts1 = MAVROS local time in ns

PX4 replies:
  tc1 = PX4 local time in ns
  ts1 = the original MAVROS timestamp

MAVROS receives:
  now = MAVROS local receive time in ns
```

MAVROS computes RTT using only its own clock:

```text
rtt_ns = now - ts1
```

This means RTT measurement does not require the MAVROS and PX4 clocks to be
already synchronized. PX4 only needs to return the original `ts1` value.

PX4's reply is built into PX4's MAVLink module. When PX4 receives a `TIMESYNC`
message whose `tc1 == 0`, it stamps `tc1` with the PX4 time and sends the
message back with `ts1` unchanged.

## Time Offset Estimate

The same packet exchange is also used to estimate the time offset between the
two systems. Assuming the uplink and downlink delays are roughly symmetric,
MAVROS estimates:

```text
offset_ns = (ts1 + now - 2 * tc1) / 2
```

After the filter converges, MAVROS uses this offset to translate PX4 timestamps
such as `time_boot_ms` or `time_usec` into ROS `header.stamp` values. If the
filter has not converged, MAVROS falls back to `ros::Time::now()` for received
message stamps.

## Warning Thresholds

MAVROS defaults:

```text
time/max_rtt_sample = 10 ms
time/max_consecutive_high_rtt = 5
```

An RTT sample at or above the threshold is rejected from the timesync filter.
After more than five consecutive high-RTT samples, MAVROS prints the
`TM : RTT too high for timesync` warning and resets the high-RTT warning
counter.

PX4 v1.12 has similar built-in constants:

```text
MAX_RTT_SAMPLE = 10 ms
MAX_CONSECUTIVE_HIGH_RTT = 5
```

The `TM : ...` line seen in a ROS/MAVROS console is the MAVROS-side warning.
PX4 can also warn on its own console/log when it runs its own timesync filter
and sees repeated high RTT samples.

## Baud-Rate Implications

The measured path is:

```text
MAVROS
  -> UDP 14560
  -> mavlink-routerd
  -> /dev/ttyS7
  -> PX4
  -> /dev/ttyS7
  -> mavlink-routerd
  -> UDP 14560
  -> MAVROS
```

At `115200` baud, high-rate MAVLink streams can queue ahead of the `TIMESYNC`
request or response on the serial link. The reported RTT therefore includes
serial transmission time, queueing in `mavlink-routerd`, queueing in PX4/MAVROS,
and the return path.

An observed `30 ms` RTT warning does not mean the warning threshold is 30 ms.
The default threshold is 10 ms; 30 ms is the measured sample value.

## Hard rule: 921600

FS150 companion ↔ PX4 UART **must** stay at `921600`. This is not optional.

At `115200`, high-rate MAVLink streams queue on the serial link. That raises
companion↔FC RTT, can block or jitter other MAVLink traffic, and has produced
TIMESYNC RTT samples **above 30 ms** in the field (default MAVROS warning
threshold is ~10 ms; 30 ms was a measured sample, not the threshold).

Do **not** lower packaged `Baud = 921600` in
`/etc/xgc2/fs150-mavlink-router/router.conf` to “get a heartbeat faster.”
If `xgc2-fs150-mavlink-router` is up at 921600 but QGC/MAVROS see no HEARTBEAT,
check and set the matching PX4 serial baud (typically `SER_TELx_BAUD` for the
wired TELEM/UART used on that airframe) via QGC **wired serial**, then retest
UDP `14560` / TCP `5760`. Stop conflicting legacy units
(`startMavRoute`, `fs150-mavlink-router`) so they do not hold `/dev/ttyS7`.

Low-baud experiments remain debug-only. If you must temporarily test `115200`,
reduce or filter high-rate streams such as `HIGHRES_IMU` (`105`), optical flow
(`106`), and odometry (`331`); never ship that as the product default.

