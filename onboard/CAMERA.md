# FS150 camera assembly

This robot does not own a camera driver. It parameterizes the common stack.

| Role | Package / unit |
| --- | --- |
| Capture + one H264 | `xgc_native_v4l2_rtp` (`--device /dev/video8 --pixel-format nv12`) |
| WebRTC | `xgc-media-edge` + `config/media-sources.json` |
| Optional ROS Image | only if you later add `xgc2_camera_driver` **instead of** the native RTP owner, not both |
| Forbidden default | `camera_ros`, `ros_image_rtp_adapter`, `ros_fallback_rtp` |

Gazebo FS150 SITL cameras stay in `gazebo_sim_camera` (native RTP).
