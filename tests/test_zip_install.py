#!/usr/bin/env python3
"""ZIP transaction acceptance on synthetic packages and injected SSH. No network."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import re
import subprocess
import sys
import tarfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile
import test_release_plan as plans
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/setup/gui'))
sys.path.insert(0,str(ROOT/'packaging/release'))
import install as installer

class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.base=plans.PlanTests();self.base.setUp();self.addCleanup(self.base.doCleanups)
        self.root=self.base.fixture.root;self.session=self.root/'session'
        self.archive=next((self.root/'out').glob('*.zip'))
        self.image=self.root/'recovery.bin';self.image.write_bytes(b'synthetic recovery')
        self.hash=hashlib.sha256(self.image.read_bytes()).hexdigest()
        for module in (installer,installer.fresh):
            ctx=patch.object(module,'RECOVERY_SHA',self.hash);ctx.start();self.addCleanup(ctx.stop)
        self.conn={'host':'192.0.2.1','source':'192.0.2.2','known_hosts':'unused','known_hosts_sha256':'unused'}
        self.raw=self.base.raw;self.writes=0;self.calls=[];self.failure=None
        self.inventory=installer.plan.snapshot(self.raw)[1]
        self.protected=b'fixed protected state\n'
    def backup(self):
        inner=io.BytesIO()
        with tarfile.open(fileobj=inner,mode='w') as t:
            info=tarfile.TarInfo('upper/etc/config/system');blob=b'synthetic configuration';info.size=len(blob);t.addfile(info,io.BytesIO(blob))
        outer=io.BytesIO()
        values={'identity.txt':b'02:00:00:00:00:01\nsynthetic-boot\n',
                'inventory.txt':''.join(n+' - '+v+'\n' for n,v in sorted(self.inventory.items())).encode(),
                'protected.txt':self.protected,'overlay.tar':inner.getvalue()}
        with tarfile.open(fileobj=outer,mode='w') as t:
            for name,blob in values.items():
                info=tarfile.TarInfo(name);info.size=len(blob);t.addfile(info,io.BytesIO(blob))
        blob=outer.getvalue()
        return hashlib.sha256(blob).hexdigest().encode()+b'  backup.tar\n'+blob
    def remote(self,command,**kwargs):
        self.calls.append(command)
        subprocess.run(['sh','-n'],input=command.encode(),check=True)
        if 'printf \'complete' in command: return SimpleNamespace(stdout=self.raw.encode())
        if 'cat "$d/backup.tar"' in command:
            return SimpleNamespace(stdout=b'corrupt' if self.failure=='backup' else self.backup())
        if 'opkg install ' in command:
            if self.failure=='binding': raise subprocess.CalledProcessError(1,['mock-ssh'])
            self.writes+=1
            with tarfile.open(fileobj=io.BytesIO(kwargs['input'])) as t:
                self.assertEqual(len(t.getnames()),36)
                self.assertTrue(all('/' not in n for n in t.getnames()))
            if self.failure=='timeout': raise subprocess.TimeoutExpired(['mock-ssh'],240)
        if 'GUI_FRESH_VERIFIED' in command:
            if self.failure=='verify': raise subprocess.CalledProcessError(1,['mock-ssh'])
            return SimpleNamespace(stdout=b'no proof' if self.failure=='proof' else b'GUI_FRESH_VERIFIED\n')
        return SimpleNamespace(stdout=b'')
    def prepare(self):
        installer.prepare(self.session,self.archive,self.image,self.conn,self.remote,lambda _:None)
    def resume(self,action='install',confirm='INSTALL 192.0.2.1'):
        installer.resume(self.session,action,lambda _:self.remote,confirm,lambda _:None)
    def test_complete_and_verify(self):
        self.prepare();self.assertEqual(self.writes,0)
        self.assertTrue((self.session/'overlay.tar').is_file())
        self.resume();self.resume('verify');self.assertEqual(self.writes,1)
        self.assertTrue((self.session/'verified.json').is_file())
        self.assertTrue(any('synthetic-boot' in c and 'cmp "$d/protected.txt"' in c for c in self.calls))
        with self.assertRaises(ValueError): self.resume()
    def test_timeout_blocks_retry_and_allows_verification(self):
        self.prepare();self.failure='timeout'
        with self.assertRaises(subprocess.TimeoutExpired): self.resume()
        with self.assertRaises(ValueError): self.resume()
        self.assertEqual(self.writes,1);self.failure=None;self.resume('verify')
        self.assertTrue((self.session/'verified.json').exists())
    def test_failed_verification_removes_old_proof(self):
        self.prepare();self.resume();self.failure='verify'
        with self.assertRaises(subprocess.CalledProcessError): self.resume('verify')
        self.assertFalse((self.session/'verified.json').exists())
    def test_missing_proof_is_not_success(self):
        self.prepare();self.failure='proof'
        with self.assertRaises(ValueError): self.resume()
        self.assertFalse((self.session/'verified.json').exists())
        self.assertTrue((self.session/'write-started').exists())
    def test_corrupt_backup_refuses_preparation(self):
        self.failure='backup'
        with self.assertRaises(ValueError): self.prepare()
        self.assertFalse((self.session/'session.json').exists());self.assertEqual(self.writes,0)
    def test_changed_inventory_cannot_publish_preparation(self):
        self.inventory['unexpected']='1'
        with self.assertRaises(ValueError): self.prepare()
        self.assertFalse((self.session/'session.json').exists())
    def test_corrupt_saved_evidence(self):
        self.prepare()
        for name in ('overlay.tar','backup.tar','openwrt-recovery.bin','bundle.zip','prepared.json','payload/bundle/manifest.json'):
            path=self.session/name;old=path.read_bytes();path.write_bytes(b'corrupt')
            with self.subTest(name=name),self.assertRaises((ValueError,json.JSONDecodeError)): self.resume()
            path.write_bytes(old)
        self.assertEqual(self.writes,0)
    def test_expiry(self):
        self.prepare()
        with patch.object(installer.fresh.time,'time',return_value=10**12),self.assertRaises(ValueError):self.resume()
        self.assertFalse((self.session/'write-started').exists());self.assertEqual(self.writes,0)
    def test_live_binding_refusal_keeps_unknown_marker(self):
        self.prepare();self.failure='binding'
        with self.assertRaises(subprocess.CalledProcessError):self.resume()
        self.assertEqual(self.writes,0);self.assertTrue((self.session/'write-started').exists())
        with self.assertRaises(ValueError): self.resume()
    def test_confirmation_before_remote(self):
        self.prepare();calls=len(self.calls)
        with self.assertRaises(ValueError): self.resume(confirm='INSTALL 192.0.2.3')
        self.assertEqual(len(self.calls),calls);self.assertFalse((self.session/'write-started').exists())
    def test_existing_session_and_concurrent_guard(self):
        self.prepare();old=(self.session/'session.json').read_bytes()
        with self.assertRaises(FileExistsError):self.prepare()
        self.assertEqual(old,(self.session/'session.json').read_bytes())
        with installer.guard(self.session):
            with self.assertRaises(FileExistsError): self.resume()
        self.assertEqual(self.writes,0)
    def test_wrong_image_no_device_calls(self):
        self.image.write_bytes(b'wrong')
        with self.assertRaises(ValueError):self.prepare()
        self.assertEqual(self.calls,[])
    def test_ssh_arguments_and_no_key_autoaccept(self):
        known=self.root/'known hosts';known.write_text('synthetic trust')
        conn=installer.connection('192.0.2.1','192.0.2.2',known)
        ssh=installer.SSH(conn)
        self.assertIn('StrictHostKeyChecking=yes',ssh.command)
        self.assertIn('-b',ssh.command);self.assertNotIn('StrictHostKeyChecking=no',ssh.command)
        with patch.object(installer.subprocess,'run',return_value=SimpleNamespace(stdout=b'ok')) as run:
            ssh('true',stdout=subprocess.PIPE)
            self.assertIn('mkdir /tmp/schoolbell-release.lock',run.call_args[0][0][-1])
            self.assertTrue(run.call_args[1]['check']);self.assertEqual(run.call_args[1]['timeout'],240)
        known.write_text('changed')
        with self.assertRaises(ValueError):installer.SSH(conn)
    def shell_target(self, changed=False):
        # Execute generated POSIX guards/transfers against a private fake filesystem.
        fs=self.root/'fake-device';fs.mkdir()
        files={'etc/openwrt_release':"DISTRIB_RELEASE=19.07.9\nDISTRIB_TARGET=ramips/mt76x8\nDISTRIB_ARCH=mipsel_24kc\n",
               'tmp/sysinfo/board_name':'tplink,tl-mr3020-v3\n',
               'sys/class/net/br-lan/address':('different' if changed else '02:00:00:00:00:01')+'\n',
               'proc/sys/kernel/random/boot_id':'synthetic-boot\n',
               'inventory':''.join(n+' - '+v+'\n' for n,v in sorted(self.inventory.items())),
               'after':''.join(n+' - '+v+'\n' for n,v in sorted(self.inventory.items()))+''.join(row['name']+' - '+row['version']+'\n' for row in self.base.fixture.rows)}
        for name,text in files.items():
            path=fs/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
        for service in ('schoolbell-auto','uhttpd'):
            path=fs/'etc/init.d'/service;path.parent.mkdir(exist_ok=True)
            path.write_text('#!/bin/sh\nexit 0\n');path.chmod(0o755)
        prefix="""id() { echo 0; }
opkg() {
 case "$1" in
 status) awk -F ' - ' -v n="$2" '$1==n {print "Version: " $2}' INVENTORY;;
 list-installed) cat INVENTORY;;
 install) cp AFTER INVENTORY; echo written > WRITTEN;;
 *) return 1;;
 esac
}
df() { printf 'Filesystem 1K-blocks Used Available Use%% Mounted\\nfixture 200000 0 100000 0%% /\\n'; }
""".replace('INVENTORY',str(fs/'inventory')).replace('AFTER',str(fs/'after')).replace('WRITTEN',str(fs/'written'))
        def execute(command,**kwargs):
            command=command.replace(installer.fresh.PROTECTED,"printf 'fixed protected state\\n'\n")
            command=command.replace(installer.OFF,'true\n')
            command=re.sub(r'(?<![A-Za-z0-9_./-])/(tmp|etc|sys|proc)/',lambda m:str(fs)+m[0],command)
            return subprocess.run(['sh','-c',prefix+command],check=True,timeout=10,**kwargs)
        return fs,execute
    def test_generated_shell_actually_checks_and_installs(self):
        self.prepare();fs,remote=self.shell_target()
        installer.resume(self.session,'install',lambda _:remote,'INSTALL 192.0.2.1',lambda _:None)
        self.assertTrue((fs/'written').is_file());self.assertTrue((self.session/'verified.json').is_file())
    def test_generated_shell_refuses_changed_device(self):
        self.prepare();fs,remote=self.shell_target(changed=True)
        with self.assertRaises(subprocess.CalledProcessError):
            installer.resume(self.session,'install',lambda _:remote,'INSTALL 192.0.2.1',lambda _:None)
        self.assertFalse((fs/'written').exists());self.assertFalse((self.session/'verified.json').exists())
    def test_generated_shell_refuses_changed_inventory(self):
        self.prepare();fs,remote=self.shell_target()
        with (fs/'inventory').open('a') as stream:stream.write('unexpected - 1\n')
        with self.assertRaises(subprocess.CalledProcessError):
            installer.resume(self.session,'install',lambda _:remote,'INSTALL 192.0.2.1',lambda _:None)
        self.assertFalse((fs/'written').exists())
    def test_generated_shell_refuses_changed_settings(self):
        self.protected=b'original protected state\n';self.prepare();fs,remote=self.shell_target()
        with self.assertRaises(subprocess.CalledProcessError):
            installer.resume(self.session,'install',lambda _:remote,'INSTALL 192.0.2.1',lambda _:None)
        self.assertFalse((fs/'written').exists())
    def test_original_zip_replacement_cannot_change_session(self):
        self.prepare();self.archive.write_bytes(b'replaced original download')
        self.resume();self.assertEqual(self.writes,1)
    def test_truncated_zip_before_ssh(self):
        self.archive.write_bytes(self.archive.read_bytes()[:100])
        with self.assertRaises(zipfile.BadZipFile):self.prepare()
        self.assertEqual(self.calls,[])
    def test_unsafe_zip_inputs(self):
        for names,kind in [(['../escape'],'file'),(['schoolbell-v5.1.127/A','schoolbell-v5.1.127/a'],'file'),(['schoolbell-v5.1.127/CON.txt'],'file'),(['schoolbell-v5.1.127/link'],'link'),(['schoolbell-v5.1.127/file','other/file'],'file')]:
            buf=io.BytesIO()
            with zipfile.ZipFile(buf,'w') as z:
                for name in names:
                    info=zipfile.ZipInfo(name);info.create_system=3
                    info.external_attr=((stat.S_IFLNK if kind=='link' else stat.S_IFREG)|0o644)<<16
                    z.writestr(info,b'payload')
            with self.subTest(names=names),self.assertRaises(ValueError): installer.unpack(buf.getvalue(),self.root/'unsafe')
            self.assertFalse((self.root/'unsafe').exists())
    def test_session_inside_extracted_bundle_refused(self):
        with patch.object(installer,'__file__',str(self.base.root/'scripts/install.py')):
            with self.assertRaises(ValueError):
                with installer.guard(self.base.root/'new-session',create=True):pass
        self.assertFalse((self.base.root/'new-session').exists())
    def test_zip_bounds(self):
        for key,value in [('MAX_FILES',1),('MAX_CONTENT',1)]:
            with patch.object(installer,key,value),self.assertRaises(ValueError):installer.unpack(self.archive.read_bytes(),self.root/'bounded')
            self.assertFalse((self.root/'bounded').exists())
    def test_installed_or_residual_data_refused(self):
        self.raw=self.raw.replace('data\t0','data\t1')
        with self.assertRaises(ValueError):self.prepare()
        self.assertFalse((self.session/'session.json').exists());self.assertEqual(self.writes,0)

if __name__=='__main__':unittest.main()
