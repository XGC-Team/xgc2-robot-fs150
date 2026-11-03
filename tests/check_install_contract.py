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
    for name, key in [('start-mavros', 'MAV_SYS_ID'), ('start-mocap', 'MOCAP_RIGID_BODY')]:
        script = work / name
        script.write_text((AUTOSTART / 'scripts' / name).read_text().replace('/opt/ros/', str(work / 'absent-ros')+'/'))
        launch = work / (name+'.launch')
        launch.write_text('<launch/>')
        selected = dict(env, MAVROS_LAUNCH=str(launch), MOCAP_LAUNCH=str(launch))
        selected.pop(key, None)
        log.write_text('')
        result = subprocess.run(['bash',str(script)], env=selected, capture_output=True, text=True)
        assert result.returncode != 0 and key in result.stderr, result
        assert 'roslaunch' not in log.read_text()
        selected[key] = '5' if key == 'MAV_SYS_ID' else 'FS150_05'
        subprocess.run(['bash',str(script)], env=selected, check=True, capture_output=True)
        assert 'roslaunch' in log.read_text()
    for name, arg in [('fs150_mavros','tgt_system'),('fs150_mocap','tracker')]:
        launch = ET.parse(ROOT / 'onboard/communication/src' / name / 'launch' / ('mavros.launch' if name=='fs150_mavros' else 'mocap.launch')).getroot()
        node = next(item for item in launch.findall('arg') if item.attrib['name']==arg)
        assert 'default' not in node.attrib and 'value' not in node.attrib
print('PASS install preserves services; launch requires explicit aircraft identity')
