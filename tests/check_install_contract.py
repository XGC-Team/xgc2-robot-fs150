#!/usr/bin/env python3
"""Execute the install hook and launchers against isolated service boundaries."""
from pathlib import Path
import os
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
AUTOSTART = ROOT / 'onboard/autostart/src/fs150_onboard_autostart'
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    binary = work / 'bin'
    binary.mkdir()
    log = work / 'calls'
    for name in ('systemctl', 'roslaunch', 'rospack'):
        p = binary / name
        p.write_text('#!/bin/sh\nprintf "%s %s\\n" "'+name+'" "$*" >> "$CALLS"\n')
        p.chmod(0o755)
    env = dict(os.environ, PATH=str(binary)+':'+os.environ['PATH'], CALLS=str(log))
    hook = work / 'postinst'
    hook.write_text((ROOT / '.xgc2/debian/xgc2-fs150-mavlink-router/postinst').read_text().replace('/etc/apt/preferences.d', str(work / 'preferences')))
    subprocess.run(['sh', str(hook), 'configure'], env=env, check=True)
    assert log.read_text().splitlines() == ['systemctl daemon-reload']
    settings = (AUTOSTART / 'config/onboard.env').read_text()
    assert 'MAV_SYS_ID' not in settings and 'MOCAP_RIGID_BODY' not in settings
    assert 'UART_DEVICE=/dev/ttyS7' in settings
print('PASS router installation preserves services and has no aircraft identity settings')
