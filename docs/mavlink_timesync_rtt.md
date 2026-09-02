# FS150 MAVLink UART

Companion UART is `/dev/ttyS7` at **921600** 8N1. Do not lower packaged
`Baud` in `/etc/xgc2/fs150-mavlink-router/router.conf` to get a faster
heartbeat. Match PX4 `SER_TEL1_BAUD` to 921600. Remote: UDP `14560`
(filtered) and TCP `5760`. Onboard MAVROS: `127.0.0.1:14561` (unfiltered).

`TM : RTT too high for timesync` is MAVLink TIMESYNC RTT (default warn at
10 ms), not setpoint topic delay. Engineering notes:
`memory/now/fs150-uart-921600.md` in GitHub `xgc2-dev-memory`.
