#!/usr/bin/env python3
"""Offline planner tests: synthetic bundles and snapshots, no target access."""
import json
import subprocess
import unittest
from unittest.mock import patch
import zipfile
import test_release_bundle as fixtures
p=fixtures.module('plan','packaging/release/plan.py')

class PlanTests(unittest.TestCase):
    def setUp(self):
        # Reuse the bounded, synthetic 35-IPK builder fixture without real firmware.
        self.fixture=fixtures.ReleaseTests();self.fixture.setUp();self.addCleanup(self.fixture.doCleanups)
        f=self.fixture
        f.lock['firmware']=dict(p.ABI);f.doc['firmware']=dict(p.ABI)
        for path in (f.repo/'packaging/offline/openwrt-19.07.9-mipsel_24kc.json',f.bundle/'dependencies.lock.json'):
            path.write_text(json.dumps(f.lock))
        f.save();archive=f.build()
        self.root=f.root/'extracted'
        with zipfile.ZipFile(archive) as z: z.extractall(self.root)
        self.root=self.root/'schoolbell-v5.1.127'
        self.raw='format\t1\nboard\ttplink,tl-mr3020-v3\nopenwrt\t19.07.9\ntarget\tramips/mt76x8\narchitecture\tmipsel_24kc\noverlay_kib\t100000\ntmp_kib\t100000\npending\t0\ndata\t0\nautomatic\toff\n'
        self.raw+=''.join('package\t'+n+'\t'+v+'\n' for n,v in p.ABI.items())+'complete\t1\n'
    def rehash(self):
        (self.root/'SHA256SUMS').write_text(''.join(p.sha(f)+'  '+f.relative_to(self.root).as_posix()+'\n' for f in sorted(self.root.rglob('*')) if f.is_file() and f.name!='SHA256SUMS'))
    def test_fresh_and_retained(self):
        report=p.plan(self.root,self.raw+'package\tdep2\t1\n')
        self.assertEqual(len(report['install']),34);self.assertEqual(report['mode'],'fresh')
        self.assertFalse(report['write_authorized']);self.assertEqual(report['status'],'preliminary-only')
        self.assertGreater(report['required_overlay_kib'],512)
        self.assertGreater(report['required_tmp_kib'],4096)
    def test_current_is_no_write(self):
        raw=self.raw.replace('data\t0','data\t1')+''.join('package\t'+r['name']+'\t'+r['version']+'\n' for r in self.fixture.rows)
        report=p.plan(self.root,raw);self.assertEqual(report['install'],[])
        self.assertEqual(report['mode'],'already-current');self.assertEqual(report['required_overlay_kib'],0)
    def test_refuse_upgrade_and_repair(self):
        for version in ('5.1.124','5.1.127','99.0.0'):
            with self.subTest(version=version),self.assertRaises(ValueError): p.plan(self.root,self.raw+'package\tmodbus-schoolbell\t'+version+'\n')
    def test_refuse_state_and_abi(self):
        for old,new in [('19.07.9','23.05.0'),('mipsel_24kc','aarch64'),('data\t0','data\t1'),('pending\t0','pending\t1'),('automatic\toff','automatic\ton'),('1.1.24-2','wrong')]:
            with self.subTest(new=new),self.assertRaises(ValueError):p.plan(self.root,self.raw.replace(old,new))
    def test_refuse_truncation_duplicates_and_space(self):
        for raw in (self.raw.replace('complete\t1\n',''),self.raw+'data\t0\n', self.raw+'package\tlibc\t1.1.24-2\n',self.raw.replace('100000','0'),self.raw.replace('100000','-1'),self.raw.replace('100000','NaN')):
            with self.subTest(raw=raw),self.assertRaises(ValueError):p.plan(self.root,raw)
    def test_space_boundary(self):
        report=p.plan(self.root,self.raw)
        raw=self.raw.replace('overlay_kib\t100000','overlay_kib\t'+str(report['required_overlay_kib'])).replace('tmp_kib\t100000','tmp_kib\t'+str(report['required_tmp_kib']))
        p.plan(self.root,raw)
        with self.assertRaises(ValueError):p.plan(self.root,raw.replace('tmp_kib\t'+str(report['required_tmp_kib']),'tmp_kib\t'+str(report['required_tmp_kib']-1)))
    def test_wrong_installed_dependency(self):
        with self.assertRaises(ValueError):p.plan(self.root,self.raw+'package\tdep2\t2\n')
    def test_corrupt_and_extra_files(self):
        (self.root/'extra').write_text('unlisted')
        with self.assertRaises(ValueError):p.plan(self.root,self.raw)
        (self.root/'extra').unlink();(self.root/'README.md').write_text('corrupt')
        with self.assertRaises(ValueError):p.plan(self.root,self.raw)
    def test_rehashed_bad_metadata(self):
        doc=json.loads((self.root/'manifest.json').read_bytes());doc['packages'][0]['version']='99.0.0'
        (self.root/'manifest.json').write_text(json.dumps(doc));self.rehash()
        with self.assertRaises(ValueError):p.plan(self.root,self.raw)
    def test_rehashed_duplicate_and_path(self):
        path=self.root/'manifest.json';original=json.loads(path.read_bytes())
        for filename in ('../outside.ipk',original['packages'][0]['file']):
            doc=json.loads(json.dumps(original));doc['packages'][1]['file']=filename;path.write_text(json.dumps(doc));self.rehash()
            with self.assertRaises(ValueError):p.plan(self.root,self.raw)
    def test_stock_alternative_and_dependency_constraint(self):
        raw=self.raw+'package\tdep2\tstock\n'
        with patch.dict(p.STOCK, {'dep2':'stock'}):
            report=p.plan(self.root,raw)
            self.assertIn({'name':'dep2','version':'stock'},report['retain'])
            doc,rows,digest=p.bundle(self.root)
            rows[0]['depends']='dep2 (= 1)'
            with patch.object(p,'bundle',return_value=(doc,rows,digest)),self.assertRaises(ValueError):p.plan(self.root,raw)
    def test_cli_repeat_does_not_modify_bundle(self):
        source=self.fixture.root/'snapshot.tsv';source.write_text(self.raw)
        before={str(f):f.read_bytes() for f in self.root.rglob('*') if f.is_file()}
        for _ in range(2):
            result=subprocess.run(['python3',str(self.root/'scripts/plan.py'),'--snapshot',str(source)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse(json.loads(result.stdout)['write_authorized'])
        self.assertEqual(before,{str(f):f.read_bytes() for f in self.root.rglob('*') if f.is_file()})
    def test_snapshot_syntax(self):
        subprocess.run(['sh','-n',str(self.root/'scripts/snapshot.sh')],check=True)

if __name__=='__main__': unittest.main()
