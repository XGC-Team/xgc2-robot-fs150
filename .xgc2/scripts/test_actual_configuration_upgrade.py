#!/usr/bin/env python3
"""Actual old/new router .deb upgrade, including unmodified maintainer scripts.

Run as root ONLY in a fresh disposable Docker container with the real declared
xgc2-mavlink-router dependency already installed. Pass old.deb new.deb. Does not
start a router. A systemctl boundary recorder rejects enable/start/restart.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

PACKAGE = 'xgc2-fs150-mavlink-router'
CONFIGS = [Path('/etc/xgc2/fs150-mavlink-router/router.conf'),
           Path('/etc/xgc2/fs150/onboard.env')]


def run(*args):
    result = subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=60)
    print(result.stdout, end='')
    return result.stdout


def main(old, new):
    if os.geteuid() != 0 or not Path('/.dockerenv').exists():
        raise SystemExit('Requires root in a fresh disposable Docker container')
    # No force-depends: a missing genuine dependency must fail configuration.
    run('dpkg-query', '-W', '-f=${db:Status-Status}\n', 'xgc2-mavlink-router')
    status = subprocess.run(['dpkg-query', '-W', '-f=${db:Status-Status}', PACKAGE],
                            text=True, capture_output=True)
    if status.returncode == 0 and status.stdout != 'not-installed':
        raise SystemExit('Refusing a container with existing FS150 router state')
    for p in CONFIGS:
        if p.exists(): raise SystemExit('Refusing preexisting FS150 configuration')
    with tempfile.TemporaryDirectory(prefix='actual-fs150-upgrade-') as temp:
        root = Path(temp)
        fresh = root/'new-payload'
        run('dpkg-deb', '--extract', new, str(fresh))
        new_factory = {p: (fresh/str(p).lstrip('/')).read_bytes() for p in CONFIGS}
        log = root/'systemctl.log'
        (root/'systemctl').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >>"$FS150_SYSTEMCTL_LOG"\n'
                                    'case "$1" in start|enable|restart|try-restart) exit 97;; esac\nexit 0\n')
        (root/'systemctl').chmod(0o755)
        os.environ['PATH'] = str(root)+':'+os.environ['PATH']
        os.environ['FS150_SYSTEMCTL_LOG'] = str(log)
        for edited in (False, True):
            run('dpkg', '--force-confold', '--install', old)
            factory = {p: p.read_bytes() for p in CONFIGS}
            expected = {p: v + b'\n# isolated operator change\n' if edited else new_factory[p]
                        for p,v in factory.items()}
            if edited:
                for p,value in expected.items(): p.write_bytes(value)
            override = Path('/etc/xgc2/fs150-mavlink-router/config.d/local.conf')
            override.write_text('# isolated override\n')
            before_upgrade = len(log.read_text().splitlines()) if log.exists() else 0
            run('dpkg', '--force-confold', '--install', new)
            run('dpkg', '--force-confold', '--install', new)
            upgrade_calls = log.read_text().splitlines()[before_upgrade:]
            assert all(line.split()[0] == 'daemon-reload' for line in upgrade_calls), upgrade_calls
            for p,value in expected.items(): assert p.read_bytes() == value, p
            assert override.read_text() == '# isolated override\n'
            recorded = run('dpkg-query', '-W', '-f=${Conffiles}', PACKAGE)
            assert all(str(p) in recorded for p in CONFIGS)
            run('dpkg', '--remove', PACKAGE)
            for p,value in expected.items(): assert p.read_bytes() == value, p
            assert override.exists()
            run('dpkg', '--purge', PACKAGE)
            assert not any(p.exists() for p in CONFIGS)
            assert not override.exists()  # actual product postrm purge contract
            print('PASS actual old->new repeated upgrade/remove/purge edited='+str(edited))
        commands = log.read_text().splitlines()
        assert commands, 'maintainer scripts did not reach systemctl boundary'
        assert not any(line.split()[0] in ('start','enable','restart','try-restart')
                       for line in commands), commands
        print('PASS actual maintainer scripts: no enable/start/restart; calls='+str(len(commands)))


if __name__ == '__main__':
    if len(sys.argv) != 3: raise SystemExit(__doc__)
    main(*sys.argv[1:])
