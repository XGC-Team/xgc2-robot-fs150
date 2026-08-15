# FS150 sensors

Optional camera assembly. Sibling of `communication` and `autostart`.
Not min-boot. Capture is the shared `xgc2_camera_driver`.

```text
src/fs150_onboard_sensors    compose launch + media-sources.json
legacy/camera_ros            field fork; do not launch
```

## Contract

```text
rkisp /dev/video8  --native capture owner-->  xgc2_camera_driver / xgc_native_v4l2_rtp
                                              --> 127.0.0.1:5004 + control socket
xgc-media-edge     --WebRTC-->  browser :18090
```

Do **not** start `xgc_ros_image_rtp` or `camera_ros` on this device unless
something else already holds `/dev/video8`.

LIVE 2026-08-15: `/dev/video8` = `rkisp_mainpath`. `rkaiq_3A` must be running.

```bash
sudo systemctl start xgc2-fs150-camera.service
sudo systemctl start xgc2-fs150-media-edge.service
# http://<wlan0>:18090/?source=fs150_cam
```
