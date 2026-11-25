#!/usr/bin/env python3
"""Portable distribution: exclusions, stale builds, corruption and atomic outputs."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('wizard_release',ROOT/'scripts/build-wizard-release.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Packaging(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.build=self.root/'build';self.build.mkdir()
        for name,source in m.SOURCES.items():
            target=self.build/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
        (self.build/'schoolbell-setup-wizard.exe').write_bytes(b'MZtest fixture, not an executable')
        (self.build/'firmware').mkdir();(self.build/'firmware/tp_recovery.bin').write_bytes(b'image fixture')
        self.pin=patch.object(m,'OPENWRT_SHA',m.digest(b'image fixture'));self.pin.start();self.addCleanup(self.pin.stop)
        (self.build/'build-receipt.json').write_text(json.dumps({'version':(m.GUI/'wizard-version.txt').read_text().strip(),
            'exe_sha256':m.digest((self.build/'schoolbell-setup-wizard.exe').read_bytes()),
            'firmware_check':'passed','system_dlls_only':True}))
    def pack(self,name='out'):
        return m.build_archive(self.build,self.root/name)
    def test_reproducible_and_private_exclusions(self):
        (self.build/'password.txt').write_text('never distribute')
        (self.build/'session').mkdir();(self.build/'session/overlay.tar').write_bytes(b'private')
        a=self.pack();b=self.pack('second');self.assertEqual(a.read_bytes(),b.read_bytes())
        with zipfile.ZipFile(a) as z:
            names=z.namelist();self.assertFalse(any('password' in n or 'overlay' in n for n in names))
            manifest=json.loads(z.read(next(n for n in names if n.endswith('/manifest.json'))))
            self.assertFalse(manifest['hardware_validated'])
            self.assertIn('python/python.exe',manifest['files'])
    def test_stale_worker(self):
        (self.build/'package_worker.py').write_text('old version')
        with self.assertRaisesRegex(ValueError,'Stale'):self.pack()
        self.assertFalse((self.root/'out').exists())
    def test_missing_worker(self):
        (self.build/'FlashHelperCore.ps1').unlink()
        with self.assertRaises(ValueError):self.pack()
    def test_corrupt_firmware(self):
        (self.build/'firmware/tp_recovery.bin').write_bytes(b'bad')
        with self.assertRaisesRegex(ValueError,'Unpinned'):self.pack()
    def test_stale_executable(self):
        (self.build/'schoolbell-setup-wizard.exe').write_bytes(b'MZdifferent')
        with self.assertRaisesRegex(ValueError,'receipt'):self.pack()
    def test_existing_output_preserved(self):
        (self.root/'out').mkdir();(self.root/'out/keep').write_bytes(b'keep')
        with self.assertRaises(ValueError):self.pack()
        self.assertEqual((self.root/'out/keep').read_bytes(),b'keep')
    def test_symlink(self):
        target=self.build/'package_worker.py';target.unlink()
        try:target.symlink_to(m.SOURCES['package_worker.py'])
        except OSError:self.skipTest('symlink unavailable on this host')
        with self.assertRaisesRegex(ValueError,'linked'):self.pack()

if __name__=='__main__':unittest.main()
