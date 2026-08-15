# FS150 mocap

Each aircraft runs its own `vrpn_client_ros` and names **one** Motive
tracker. `refresh_tracker_frequency` is 0, so the client does not ingest
every rigid body on the server.

Default tracker: `FS150_01`. Same string as the Adapter `mocap_rigid_body`
and as Motive. Pattern `^[A-Za-z][A-Za-z0-9_]*$`. Change
`MOCAP_RIGID_BODY` / `tracker:=` when MAV_SYS_ID is not 1
(`FS150_02` …). Do not use a generic `uav1` next to a Scout `Scout1`.

`vrpn_relay` then:

- copies pose / twist / accel onto `/pose`, `/twist`, `/accel`
- for PX4 only, also copies pose onto `/mavros/vision_pose/pose`

Vision policy (target 30 Hz): faster mocap drops frames immediately
(per-frame min-period, no queue); slower mocap publishes every accepted
sample (no hold). Quality rejects non-finite values, bad quaternions,
`(0,0)` origin, `|xy|>900`, jumps > 2 m, and a frozen tracker.

Scout vehicles use the same relay with `vision_out` empty.
