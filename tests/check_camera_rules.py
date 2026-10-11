#!/usr/bin/env python3
"""Static FS150 native camera gate; media-edge is the sole device owner."""

import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def check(root):
    onboard = root / "onboard"
    assert not (onboard / "sensors/legacy").exists(), "the replaced camera node must not ship"
    roster = onboard / "sensors/src/fs150_onboard_sensors/config/media-sources.json"
    (source,) = json.loads(roster.read_text())["sources"]
    assert source["kind"] == "pipeline" and "controlSocket" not in source, roster
    pipeline = source["pipeline"]
    assert re.fullmatch(r"(?:x264|nvv4l2|mpp)-v4l2src-(?:raw|mjpeg)", pipeline["template"]), roster
    assert pipeline["parameters"]["device"].startswith("/dev/"), roster
    assert not pipeline.get("producer"), "FS150 must not run a second camera producer"
    for path in onboard.rglob("*.launch"):
        launch = ET.parse(path).getroot()
        for node in launch.iter("node"):
            assert not re.search(r"camera|usb_cam|gscam", node.get("pkg", "")), (path, "second device owner")
        for include in launch.iter("include"):
            assert not re.search(r"camera|usb_cam|gscam", include.get("file", "")), (path, "second device owner")
    for path in onboard.rglob("*"):
        if not path.is_file() or (path.suffix not in (".cpp", ".hpp", ".h", ".py") and "scripts" not in path.parts):
            continue
        text = path.read_text(encoding="utf-8")
        assert not re.search(r"v4l2src|VideoCapture|VIDIOC_|xgc2_camera_driver_node|xgc_(?:native_v4l2_rtp|ros_image_rtp)", text), path
        assert not re.search(r"(?:open|fopen)\s*\([^\n]*[\"']/dev/video", text), path
    autostart = onboard / "autostart/src/fs150_onboard_autostart"
    script = (autostart / "scripts/start-media-edge").read_text()
    assert 'exec "${EDGE}" "${ARGS[@]}"' in script
    assert "--sources-config" in script and "--pipeline-runtime-dir" in script
    assert not (autostart / "scripts/start-camera").exists()
    unit = (autostart / "systemd/xgc2-fs150-media-edge.service").read_text()
    assert "RuntimeDirectoryMode=0700" in unit and "start-media-edge" in unit
    assert "ExecStartPre=" not in unit, "the unit must not open a camera before a lease"
    definition = json.loads((root / "process-definitions/mavros-px4-physical.json").read_text())["definitions"][0]
    command = definition["command"]
    assert command["executable"] == "roslaunch" and command["args"][:3] == ["--wait", "mavros", "px4.launch"]
    assert not re.search(r"camera|/dev/video|v4l2", json.dumps(command)), "MAVROS must not own a camera"


if __name__ == "__main__":
    check(Path(__file__).resolve().parents[1])
    print("FS150 native camera checks passed")
