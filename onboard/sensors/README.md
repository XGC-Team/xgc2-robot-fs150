# FS150 sensors

Optional camera + Media Edge assembly. Sibling of `communication` and
`autostart`. Not min-boot.

```text
src/xgc_camera_media         native V4L2 -> H264/RTP (same script as camera-ros1)
src/fs150_onboard_sensors    compose launch + media-sources.json
legacy/camera_ros            field fork; do not launch
```

## Contract

```text
rkisp /dev/video8  --native capture owner-->  xgc_native_v4l2_rtp
                                              (one H264 encode)
                                              --> 127.0.0.1:5004 + control socket
xgc-media-edge     --WebRTC-->  browser :18090
```

Do **not** start `ros_image_rtp_adapter` or `camera_ros` on this device.
ROS re-encode is only allowed if something else already holds `/dev/video8`.

Gazebo world cameras use `gazebo_sim_camera` (already native RTP). USB lab
cameras use the same `xgc_native_v4l2_rtp` with `--device` / `--pixel-format`.

LIVE 2026-08-15: `/dev/video8` = `rkisp_mainpath`. `rkaiq_3A` must be running.

```bash
# capture (install-only unit)
sudo systemctl start xgc2-fs150-camera.service
# browser
sudo systemctl start xgc2-fs150-media-edge.service
# http://<wlan0>:18090/?source=fs150_cam
```
