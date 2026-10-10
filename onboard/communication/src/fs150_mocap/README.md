# FS150 mocap

Assembly only. The client, quality gate, and vision_pose rate live in
`xgc2_vrpn_relay` (`XGC-Team/xgc2-vrpn-relay`), a compiled roscpp node shipped as
APT `ros-noetic-xgc2-vrpn-relay`, which `xgc2-fs150` depends on.

This package names **one** Motive tracker and turns vision_pose on.

The relay can take over a track that jumped away and stays there
(`jump_reacquire_s`, default 1 s in the relay). `mocap.launch` here passes 0:
a jump stays rejected until the pose is back, as before that option existed.
Enabling it is an FS150 owner decision, because PX4 EKF2 would see a step in
the vision position at the takeover.

Default tracker: `FS150_01`. Same string as the Adapter `mocap_rigid_body`
and as Motive. Pattern `^[A-Za-z][A-Za-z0-9_]*$`. Change
`MOCAP_RIGID_BODY` / `tracker:=` when MAV_SYS_ID is not 1
(`FS150_02` …).

```bash
roslaunch fs150_mocap mocap.launch tracker:=FS150_01
```
