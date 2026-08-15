# FS150 mocap

Assembly only. The client, quality gate, and vision_pose rate live in
`xgc2_vrpn_relay` (`XGC-Team/xgc2-vrpn-relay`).

This package names **one** Motive tracker and turns vision_pose on.

Default tracker: `FS150_01`. Same string as the Adapter `mocap_rigid_body`
and as Motive. Pattern `^[A-Za-z][A-Za-z0-9_]*$`. Change
`MOCAP_RIGID_BODY` / `tracker:=` when MAV_SYS_ID is not 1
(`FS150_02` …).

```bash
roslaunch fs150_mocap mocap.launch tracker:=FS150_01
```
