#!/usr/bin/env python3
"""Onboard control consumes the local router; it cannot add a GCS relay."""
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
launch=ET.parse(root/'onboard/communication/src/fs150_mavros/launch/mavros.launch').getroot()
assert launch.find("arg[@name='gcs_url']") is None, 'onboard GCS forwarding must not be configurable'
include=launch.find('include')
assert include is not None
assert include.find("arg[@name='gcs_url']").get('value')=='', 'MAVROS GCS forwarding must be disabled'
assert launch.find("arg[@name='fcu_url']").get('default')=='udp://:14551@127.0.0.1:14561'
assert all('255.255.255.255' not in (e.get('value','')+e.get('default','')) for e in launch.iter())
print('onboard MAVROS topology: local router only, no GCS relay')
