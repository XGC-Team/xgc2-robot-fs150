# FS150 camera assembly

This robot does not own a camera driver. It parameterizes the common stack.

| Role | Package / unit |
| --- | --- |
| Capture + one H264 | shared `xgc2_camera_driver` `xgc_native_v4l2_rtp` via `fs150_onboard_sensors/camera.launch` (`/dev/video8`, NV12) |
| WebRTC | `xgc-media-edge` + `config/media-sources.json` |
| Optional ROS Image | only if you later run `xgc2_camera_driver_node` **instead of** the native RTP owner, not both |
| Forbidden default | `camera_ros`, `xgc_ros_image_rtp` |

Gazebo FS150 SITL cameras stay in `gazebo_sim_camera` (native RTP).
