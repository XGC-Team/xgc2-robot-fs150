# FS150 sensors

Optional camera assembly. Sibling of `communication` and `autostart`.
Not min-boot. The camera is a Media Edge pipeline source.

```text
src/fs150_onboard_sensors    media roster: config/media-sources.json
legacy/camera_ros            field fork; do not launch
```

## Contract

```text
rkisp /dev/video8  --pipeline source fs150_cam-->  xgc-media-edge --WebRTC--> browser :18090
```

Media Edge opens the device and runs the encoder only while the source is
watched. Do **not** run `camera_ros` on this device while Media Edge may need it.

LIVE 2026-08-15: `/dev/video8` = `rkisp_mainpath`. `rkaiq_3A` must be running.

```bash
sudo systemctl start xgc2-fs150-media-edge.service
# http://<wlan0>:18090/?source=fs150_cam
```
