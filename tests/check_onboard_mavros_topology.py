#!/usr/bin/env python3
"""The onboard launcher directly uses the official MAVROS launch."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
text=(root/'onboard/autostart/src/fs150_onboard_autostart/scripts/start-mavros').read_text()
assert 'exec roslaunch mavros px4.launch' in text
assert 'gcs_url:=""' in text
assert 'udp://:14551@127.0.0.1:14561' in text
assert 'read-fcu-identity' in text
assert not (root/'onboard/communication/src/fs150_mavros').exists()
print('onboard MAVROS: official launch, verified FC identity, local Router only')
