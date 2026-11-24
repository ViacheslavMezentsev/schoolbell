#!/usr/bin/env python3
"""Release format: deterministic ZIP, exact inputs and refusal paths. No target/network."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
from license_materials import package_files
r=module('release','scripts/build-schoolbell-release.py')
b=module('ipkbuild','scripts/build-schoolbell.py')

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.bundle=self.root/'bundle';self.bundle.mkdir()
        self.repo=self.root/'repo';(self.repo/'packaging/offline').mkdir(parents=True)
        shutil.copytree(ROOT/'packaging/release',self.repo/'packaging/release')
        (self.repo/'docs/releases').mkdir(parents=True)
        (self.repo/'docs/releases/v5.1.127.md').write_text('Candidate notes')
        self.rows=[];pins=[]
        for i in range(35):
            name=['modbus-schoolbell','modbus-schoolbell-clock'][i] if i<2 else 'dep'+str(i)
            version=['5.1.127','1.0.0'][i] if i<2 else '1'
            arch='mipsel_24kc' if i==1 else 'all'
            filename=name+'_'+version+'_'+arch+'.ipk'
            control=('Package: '+name+'\nVersion: '+version+'\nArchitecture: '+arch+'\nDepends: \n').encode()
            payload={'usr/share/fixture':(b'fixture',0o644)}
            controls={'control':(control,0o644)}
            if i==0:
                payload.update(package_files('schoolbell'));payload['usr/sbin/schoolbell-auto']=(b'fixture',0o755)
                controls.update({n:(b'fixture',0o755) for n in ('preinst','postinst','prerm')})
            if i==1:
                payload.update(package_files('native'));payload['usr/lib/lua/schoolbell/clock_linux.so']=(b'\x7fELF\x01\x01\x01'+b'\0'*11+b'\x08\x00',0o755)
            data=b.tar_bytes({'debian-binary':(b'2.0\n',0o644),'control.tar.gz':(b.tar_bytes(controls),0o644),'data.tar.gz':(b.tar_bytes(payload),0o644)})
            (self.bundle/filename).write_bytes(data)
            row=dict(name=name,version=version,architecture=arch,file=filename,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),depends='')
            self.rows.append(row)
            if i>=2:pins.append(row)
        self.lock=dict(packages=pins,firmware={'libc':'test','kernel':'test'})
        (self.repo/'packaging/offline/openwrt-19.07.9-mipsel_24kc.json').write_text(json.dumps(self.lock))
        self.doc=dict(openwrt='19.07.9',target='ramips/mt76x8',architecture='mipsel_24kc',firmware=self.lock['firmware'],packages=self.rows,source_commit='a'*40,source_dirty=False)
        (self.bundle/'dependencies.lock.json').write_text(json.dumps(self.lock))
        (self.bundle/'licenses').mkdir();(self.bundle/'licenses/DEPENDENCIES.json').write_text('{"distribution_cleared":false}')
        (self.bundle/'licenses/LICENSE').write_text('fixture license')
        self.save()
        self.root_patch=patch.object(r,'ROOT',self.repo);self.root_patch.start();self.addCleanup(self.root_patch.stop)
        self.git=patch.object(r.subprocess,'check_output',side_effect=lambda args,**kw: ('b'*40+'\n') if args[1]=='rev-parse' else b'')
        self.git.start();self.addCleanup(self.git.stop)
    def save(self):
        (self.bundle/'manifest.json').write_text(json.dumps(self.doc))
        sums=''.join(r.sha(p)+'  '+p.relative_to(self.bundle).as_posix()+'\n' for p in sorted(self.bundle.rglob('*')) if p.is_file() and p.name!='SHA256SUMS')
        (self.bundle/'SHA256SUMS').write_text(sums)
    def build(self,name='out',candidate=True):return r.build(self.bundle,self.root/name,candidate)
    def test_reproducible_complete_archive(self):
        a=self.build();bb=self.build('second');self.assertEqual(a.read_bytes(),bb.read_bytes())
        with zipfile.ZipFile(a) as z:
            entries={n.split('/',1)[1]:z.read(n) for n in z.namelist()}
            m=json.loads(entries['manifest.json']);self.assertEqual(m['version'],'5.1.127');self.assertFalse(m['distribution_cleared'])
            self.assertEqual(len([n for n in entries if n.endswith('.ipk')]),35)
            self.assertNotIn('scripts/install.sh',entries)
            for line in entries['SHA256SUMS'].decode().splitlines():
                digest,name=line.split('  ');self.assertEqual(hashlib.sha256(entries[name]).hexdigest(),digest)
            self.assertEqual(entries['packages/'+self.rows[0]['file']],(self.bundle/self.rows[0]['file']).read_bytes())
        with self.assertRaises(ValueError):self.build()
    def test_public_release_blocked(self):
        with self.assertRaises(ValueError):self.build(candidate=False)
        self.assertFalse((self.root/'out').exists())
    def test_corrupt_input(self):
        (self.bundle/self.rows[0]['file']).write_bytes(b'corrupt')
        with self.assertRaises(ValueError):self.build()
    def test_rehashed_wrong_package_metadata(self):
        self.rows[0]['version']='9.0.0';self.save()
        with self.assertRaises(ValueError):self.build()
    def test_wrong_abi(self):
        self.doc['firmware']={'kernel':'wrong'};self.save()
        with self.assertRaises(ValueError):self.build()
    def test_duplicate_package(self):
        self.doc['packages'].append(self.rows[0]);self.save()
        with self.assertRaises(ValueError):self.build()
    def test_missing_dependency(self):
        self.doc['packages'].pop();self.save()
        with self.assertRaises(ValueError):self.build()
    def test_unlisted_file(self):
        (self.bundle/'secret.txt').write_text('must not enter archive')
        with self.assertRaises(ValueError):self.build()
    def test_symlink(self):
        (self.bundle/'link').symlink_to(self.bundle/'manifest.json')
        with self.assertRaises(ValueError):self.build()
    def test_checksum_path_traversal(self):
        (self.bundle/'SHA256SUMS').write_text('0'*64+'  ../outside\n')
        with self.assertRaises(ValueError):self.build()
    def test_missing_notes(self):
        (self.repo/'docs/releases/v5.1.127.md').unlink()
        with self.assertRaises(ValueError):self.build()
    def test_altered_dependency_lock(self):
        (self.bundle/'dependencies.lock.json').write_text('{}');self.save()
        with self.assertRaises(ValueError):self.build()
    def test_failed_zip_leaves_no_result(self):
        with patch.object(r.zipfile.ZipFile,'writestr',side_effect=OSError('disk full')):
            with self.assertRaises(OSError):self.build()
        self.assertFalse((self.root/'out').exists())
        self.assertEqual(list(self.root.glob('.schoolbell-release-*')),[])
    def test_notes_are_part_of_integrity(self):
        first=self.build();(self.repo/'docs/releases/v5.1.127.md').write_text('changed notes')
        second=self.build('second');self.assertNotEqual(first.read_bytes(),second.read_bytes())
    def test_shell_syntax(self):
        for script in (self.repo/'packaging/release').glob('*.sh'):
            subprocess.run(['sh','-n',str(script)],check=True)

if __name__=='__main__':unittest.main()
