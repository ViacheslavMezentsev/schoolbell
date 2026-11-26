#!/usr/bin/env python3
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pair',ROOT/'scripts/finalize-release-artifacts.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Pair(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.p=Path(self.tmp.name)
        self.w={'kind':'schoolbell-setup-wizard','package_bundle_format':1,'version':'0.3.0','source_commit':'a'*40}
        self.b={'kind':'schoolbell-package-bundle','format':1,'version':'5.1.127',
                'wizard':{'minimum_version':'0.2.1'},'assembly_commit':'a'*40,
                'packages':[{'name':'modbus-schoolbell','sha256':hashlib.sha256(b'ipk').hexdigest()}]}
        (self.p/'modbus-schoolbell_5.1.127_all.ipk').write_bytes(b'ipk')
        (self.p/'target-build.json').write_text('{}')
        self.write()
    def write(self,corrupt=False):
        for name,doc in [('schoolbell-setup-wizard-v0.3.0-windows-x86_64.zip',self.w),('schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip',self.b)]:
            data=json.dumps(doc).encode();sha=hashlib.sha256(data).hexdigest()
            with zipfile.ZipFile(self.p/name,'w') as z:
                z.writestr('root/manifest.json',data)
                z.writestr('root/SHA256SUMS',(sha if not corrupt else '0'*64)+'  manifest.json\n')
    def test_success(self):
        m.finalize(self.p);self.assertFalse(json.loads((self.p/'release-pair.json').read_text())['hardware_validated'])
        pair=json.loads((self.p/'release-pair.json').read_text())
        self.assertEqual(pair['wizard_version'],self.w['version'])
        self.assertEqual(pair['package_version'],self.b['version'])
        self.assertEqual(len((self.p/'SHA256SUMS').read_text().splitlines()),8)
        for name in m.VERIFICATION:
            self.assertEqual((self.p/name).read_bytes(),(ROOT/'packaging/release'/name).read_bytes())
    def test_wrong_commit(self):
        self.w['source_commit']='b'*40;self.write()
        with self.assertRaisesRegex(ValueError,'commits'):m.finalize(self.p)
    def test_old_wizard(self):
        self.w['version']='0.1.0';self.write()
        with self.assertRaisesRegex(ValueError,'old'):m.finalize(self.p)
    def test_corrupt_archive(self):
        self.write(corrupt=True)
        with self.assertRaisesRegex(ValueError,'checksum'):m.finalize(self.p)
    def test_other_ipk(self):
        (self.p/'modbus-schoolbell_5.1.127_all.ipk').write_bytes(b'other')
        with self.assertRaisesRegex(ValueError,'differs'):m.finalize(self.p)
    def test_no_private_files(self):
        (self.p/'overlay.tar').write_bytes(b'private')
        with self.assertRaisesRegex(ValueError,'Unexpected'):m.finalize(self.p)
        self.assertFalse((self.p/'SHA256SUMS').exists())

if __name__=='__main__':unittest.main()
