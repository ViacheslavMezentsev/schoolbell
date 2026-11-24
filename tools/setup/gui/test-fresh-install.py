import importlib.util, io, json, subprocess, tarfile, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('fresh',Path(__file__).with_name('fresh_install.py'))
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
class FreshTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name);(self.root/'bundle').mkdir();(self.root/'session').mkdir()
  self.rows=[]
  for i in range(35):
   name=['modbus-schoolbell','modbus-schoolbell-clock'][i] if i<2 else 'dependency'+str(i)
   version=['5.1.127','1.0.0'][i] if i<2 else '1'
   file=name+'_'+version+'_all.ipk';p=self.root/'bundle'/file;p.write_bytes(name.encode())
   self.rows.append(dict(name=name,version=version,file=file,sha256=f.digest(p),architecture='all',bytes=p.stat().st_size,file_blocks_estimate=4096))
  self.manifest={'package':self.rows[0],'rollback':{'version':'5.1.124'}}
  self.bundle=dict(openwrt='19.07.9',target='ramips/mt76x8',architecture='mipsel_24kc',packages=self.rows)
  (self.root/'bundle/manifest.json').write_text(json.dumps(self.bundle))
  (self.root/'firmware').mkdir();(self.root/'firmware/tp_recovery.bin').write_bytes(b'image')
  self.args=SimpleNamespace(session=str(self.root/'session'),source='192.0.2.2',index=10,action='prepare')
  self.writes=0;self.fail=False;self.changed=False;self.commands=[]
  buf=io.BytesIO()
  with tarfile.open(fileobj=buf,mode='w') as t:
   m=tarfile.TarInfo('./upper/etc');m.type=tarfile.DIRTYPE;t.addfile(m)
  self.overlay=buf.getvalue()
  real_digest=f.digest
  self.patch=patch.object(f,'digest',side_effect=lambda p:'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa' if Path(p).name in ('tp_recovery.bin','openwrt-recovery.bin') else real_digest(p))
  self.patch.start();self.addCleanup(self.patch.stop)
 def remote(self,cmd,**kw):
  self.commands.append(cmd);subprocess.run(['bash','-n'],input=cmd.encode(),check=True)
  if 'cat "$d/backup.tar"' in cmd:
   buf=io.BytesIO()
   with tarfile.open(fileobj=buf,mode='w') as t:
    for n,data in [('identity.txt',b'mac\nboot\n'),('inventory.txt',b'base - 1\n'),('overlay.tar',self.overlay),('protected.txt',b'protected\n')]:
     m=tarfile.TarInfo(n);m.size=len(data);t.addfile(m,io.BytesIO(data))
   blob=buf.getvalue();return SimpleNamespace(stdout=f.hashlib.sha256(blob).hexdigest().encode()+b'  backup.tar\n'+blob)
  if 'opkg install' in cmd:
   if self.changed:raise subprocess.CalledProcessError(1,['ssh'])
   self.writes+=1
   with tarfile.open(fileobj=io.BytesIO(kw['input'])) as t:self.assertEqual(len(t.getnames()),36)
   if self.fail:raise subprocess.TimeoutExpired(['ssh'],240)
  if self.fail and self.args.action=='verify':raise subprocess.CalledProcessError(1,['ssh'])
  return SimpleNamespace(stdout=b'GUI_FRESH_VERIFIED\n')
 def prepare(self):
  f.prepare(self.args,self.root,self.manifest,self.remote,'set -eu\n',lambda s:None)
  return json.loads((self.root/'session/prepared.json').read_text())
 def resume(self,data):f.resume(self.args,self.root,data,self.remote,'set -eu\n','true\n',lambda s:None)
 def test_large_inventory_stays_below_dropbear_command_limit(self):
  data=self.prepare();data['inventory'].update({'installed-'+str(i):'1.2.3' for i in range(1000)})
  self.args.action='install';self.resume(data)
  command=self.commands[-1]
  import shlex
  self.assertLess(len(shlex.quote(command).encode())+200,8000)
 def test_unchanged_requires_explicit_proof(self):
  data=self.prepare()
  with self.assertRaises(ValueError):f.unchanged(data,self.remote,'set -eu\n')
  def checked(cmd,**kw):
   subprocess.run(['bash','-n'],input=cmd.encode(),check=True)
   self.assertIn('cmp "$d/protected.txt"',cmd)
   self.assertIn('sha256sum -c -',cmd)
   self.assertNotIn('opkg install',cmd)
   return SimpleNamespace(stdout=b'GUI_UNCHANGED_VERIFIED\n')
  f.unchanged(data,checked,'set -eu\n')
 def test_complete_fresh_transaction(self):
  data=self.prepare();self.assertEqual(self.writes,0);self.args.action='install';self.resume(data)
  self.assertEqual(self.writes,1);self.assertTrue((self.root/'session/verified.json').exists())
  self.args.action='verify';self.resume(data);self.assertEqual(self.writes,1)
  self.assertTrue(any('cmp "$d/protected.txt"' in c for c in self.commands))
 def test_partial_install_blocks_retry(self):
  data=self.prepare();self.args.action='install';self.fail=True
  with self.assertRaises(subprocess.TimeoutExpired):self.resume(data)
  with self.assertRaises(ValueError):self.resume(data)
  self.assertEqual(self.writes,1)
 def test_backup_corruption_blocks_write(self):
  data=self.prepare();(self.root/'session/overlay.tar').write_bytes(b'bad');self.args.action='install'
  with self.assertRaises(ValueError):self.resume(data)
  self.assertEqual(self.writes,0)
 def test_changed_bundle_blocks_write(self):
  data=self.prepare();(self.root/'bundle'/self.rows[0]['file']).write_bytes(b'bad');self.args.action='install'
  with self.assertRaises(ValueError):self.resume(data)
  self.assertEqual(self.writes,0)
 def test_expired_preparation(self):
  data=self.prepare();data['created']=0;self.args.action='install'
  with self.assertRaises(ValueError):self.resume(data)
  self.assertEqual(self.writes,0)
 def test_changed_inventory_remote_blocks_write(self):
  data=self.prepare();self.changed=True;self.args.action='install'
  with self.assertRaises(subprocess.CalledProcessError):self.resume(data)
  self.assertEqual(self.writes,0)
 def test_verify_after_partial_failure_not_success(self):
  data=self.prepare();self.fail=True;self.args.action='install'
  with self.assertRaises(subprocess.TimeoutExpired):self.resume(data)
  self.args.action='verify'
  with self.assertRaises(subprocess.CalledProcessError):self.resume(data)
  self.assertFalse((self.root/'session/verified.json').exists())
 def test_wrong_connection(self):
  data=self.prepare();self.args.index=99;self.args.action='install'
  with self.assertRaises(ValueError):self.resume(data)
 def test_stock_versions_and_conflicts(self):
  rows=[dict(name='luci-base',version='other'),dict(name='new',version='1')]
  self.assertEqual(f.plan(rows,{'luci-base':f.STOCK['luci-base']}),[rows[1]])
  with self.assertRaises(ValueError):f.plan(rows,{'luci-base':'unexpected'})
 def test_unsafe_bundle_and_incomplete_bundle(self):
  self.rows[0]['file']='../escape.ipk';(self.root/'bundle/manifest.json').write_text(json.dumps(self.bundle))
  with self.assertRaises(ValueError):f.load_bundle(self.root,self.manifest['package'])
 def test_bad_backup_hash(self):
  with self.assertRaises(ValueError):f.read_backup(b'bad\nnot tar')
 def test_empty_backup_header(self):
  with self.assertRaises(ValueError):f.read_backup(b'\n')
 def test_backup_size_limit(self):
  with patch.object(f,'MAX_BACKUP_BYTES',4),self.assertRaises(ValueError):f.read_backup(b'too large')
 def test_backup_ram_admission(self):
  self.prepare()
  self.assertTrue(any('overlay_kib * 2 + 6144' in c for c in self.commands))
 def test_duplicate_inventory(self):
  with self.assertRaises(ValueError):f.inventory('x - 1\nx - 2')
if __name__=='__main__':unittest.main()
