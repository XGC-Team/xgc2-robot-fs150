#!/usr/bin/env python3
"""Check a built router .deb and exercise its configuration metadata with dpkg.

Usage: python3 .xgc2/scripts/test_configuration_upgrade.py path/to/router.deb
Only extracted configuration payload enters disposable, dependency-free fixtures.
No product maintainer scripts, ROS dependencies, or systemd services are executed.
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

CONFIGS = (
    "etc/xgc2/fs150-mavlink-router/router.conf",
    "etc/xgc2/fs150/onboard.env",
)
PACKAGE = "xgc2-fs150-config-regression"
DEB = None


def run(*args):
    result = subprocess.run(args, input="", text=True, capture_output=True,
                            timeout=60, env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise RuntimeError(f"{args!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout


class ConfigurationUpgradeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(prefix="fs150-config-test-")
        cls.addClassCleanup(cls.workspace.cleanup)
        cls.base = Path(cls.workspace.name)
        data, control = cls.base / "data", cls.base / "control"
        run("dpkg-deb", "--extract", str(DEB), str(data))
        run("dpkg-deb", "--control", str(DEB), str(control))
        conffiles = control / "conffiles"
        if not conffiles.is_file():
            raise AssertionError("built router .deb has no DEBIAN/conffiles")
        cls.metadata = conffiles.read_text()
        expected = {"/" + name for name in CONFIGS}
        if set(cls.metadata.splitlines()) != expected:
            raise AssertionError(f"unexpected conffiles: {cls.metadata!r}")
        cls.factory = {}
        for name in CONFIGS:
            source = data / name
            if source.is_symlink() or not source.is_file():
                raise AssertionError(f"configuration is not a regular file: {name}")
            cls.factory[name] = source.read_bytes()

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(dir=self.base))
        self.root = self.work / "root"
        database = self.root / "var/lib/dpkg"
        database.mkdir(parents=True)
        (database / "status").write_text("")

    def package(self, version, contents, *, legacy=False):
        stage = self.work / ("stage-" + version)
        (stage / "DEBIAN").mkdir(parents=True)
        (stage / "DEBIAN/control").write_text(
            f"Package: {PACKAGE}\nVersion: {version}\nArchitecture: all\n"
            "Maintainer: Configuration Test <test@example.invalid>\n"
            "Description: isolated FS150 configuration payload regression\n")
        if not legacy:
            (stage / "DEBIAN/conffiles").write_text(self.metadata)
        for name, value in contents.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
        archive = self.work / (version + ".deb")
        run("dpkg-deb", "--build", str(stage), str(archive))
        return archive

    def dpkg(self, *args):
        return run("dpkg", "--root=" + str(self.root),
                   "--log=" + str(self.work / "dpkg.log"),
                   "--force-not-root", "--force-confold", *map(str, args))

    def assert_contents(self, expected):
        for name, value in expected.items():
            self.assertEqual((self.root / name).read_bytes(), value, name)

    def edit_locally(self):
        edited = {name: value + b"\n# operator-owned local change\n"
                  for name, value in self.factory.items()}
        for name, value in edited.items():
            (self.root / name).write_bytes(value)
        return edited

    def test_legacy_plain_files_migrate_without_losing_edits(self):
        self.dpkg("--install", self.package("1.0", self.factory, legacy=True))
        edited = self.edit_locally()
        self.dpkg("--install", self.package("1.1", self.factory))
        self.assert_contents(edited)
        newer = {name: value + b"\n# new upstream default\n"
                 for name, value in self.factory.items()}
        self.dpkg("--install", self.package("1.2", newer))
        self.assert_contents(edited)
        self.dpkg("--install", self.work / "1.2.deb")
        self.assert_contents(edited)

    def test_clean_legacy_upgrade_keeps_factory_payload(self):
        self.dpkg("--install", self.package("1.0", self.factory, legacy=True))
        self.dpkg("--install", self.package("1.1", self.factory))
        self.assert_contents(self.factory)

    def test_unmodified_conffiles_accept_new_defaults(self):
        self.dpkg("--install", self.package("1.0", self.factory))
        newer = {name: value + b"\n# new upstream default\n"
                 for name, value in self.factory.items()}
        self.dpkg("--install", self.package("1.1", newer))
        self.assert_contents(newer)

    def test_remove_keeps_and_purge_removes_config(self):
        self.dpkg("--install", self.package("1.0", self.factory))
        edited = self.edit_locally()
        extra = self.root / "etc/xgc2/fs150-mavlink-router/config.d/operator.conf"
        extra.parent.mkdir(parents=True, exist_ok=True)
        extra.write_text("# not owned by the package\n")
        self.dpkg("--remove", PACKAGE)
        self.assert_contents(edited)
        self.assertTrue(extra.is_file())
        self.dpkg("--purge", PACKAGE)
        for name in CONFIGS:
            self.assertFalse((self.root / name).exists())
        self.assertTrue(extra.is_file())


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    DEB = Path(sys.argv.pop()).resolve(strict=True)
    unittest.main()
