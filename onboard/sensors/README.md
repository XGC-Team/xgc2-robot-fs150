# FS150 sensors

Optional onboard camera workspace. Sibling of `onboard/communication`
and `onboard/autostart`. Not part of min-boot. The camera unit lives in
`autostart` and is install-only.

```text
src/camera_ros               field V4L2 driver (rkisp / MIPI)
src/fs150_onboard_sensors    compose launch
```

2026-08-15 LIVE on `rk356x`: `/dev/video0` is `stream_cif_mipi_id0`,
`/dev/video8` is `rkisp_mainpath`. The field `camera_ros` config enables
`camera2` on `/dev/video8`. `rkaiq_3A.service` must already be running
(board image) before this node can produce frames.

Start (after ROS Noetic + this workspace are sourced):

```bash
roslaunch fs150_onboard_sensors camera.launch
```
