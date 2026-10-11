# FS150 camera assembly

This robot has no camera driver and no camera service. Media Edge runs the
camera itself, as a pipeline source: it opens `/dev/video8` and starts the
encoder when a browser, a capture or a recording needs the picture, and stops
both after the last of them has left.

| Role | Package / unit |
| --- | --- |
| Capture, one H264 encode, JPEG snapshots | `xgc-media-edge` pipeline source `fs150_cam`, template `x264-v4l2src-raw` (`/dev/video8`, NV12, 640x480 at 30) |
| Source roster | `fs150_onboard_sensors/config/media-sources.json` |
| WebRTC | unit `xgc2-fs150-media-edge.service` |
| ROS Image | none; Media Edge is the sole owner of `/dev/video8` |

Start it with `sudo systemctl start xgc2-fs150-media-edge.service` and open
`http://<wlan0 address>:18090/?source=fs150_cam`. The unit runs as `marvsmart`
with the `video` group and owns `/run/xgc2/media-edge` (mode 0700). `rkaiq_3A`
must be running for `/dev/video8` (`rkisp_mainpath`) to deliver pictures.

The software encoder is the default. For the Rockchip hardware encoder copy the
roster, use the template `mpp-v4l2src-raw` with `bitrate` in bit/s, and point
`MEDIA_SOURCES` in `/etc/xgc2/fs150/onboard.env` at the copy:

```json
"pipeline": {
  "template": "mpp-v4l2src-raw",
  "parameters": {"device": "/dev/video8", "format": "NV12", "bitrate": 2500000}
}
```

Other settings of the media service (`MEDIA_PUBLIC_IP`, `MEDIA_CONTROL_ADDRESS`,
`XGC2_TARGET_ID`) are read from the same file.
