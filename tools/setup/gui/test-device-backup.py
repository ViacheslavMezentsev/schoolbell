import importlib.util,io,json,subprocess,tarfile,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
spec=importlib.util.spec_from_file_location('backup',Path(__file__).with_name('device_backup.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
class BackupTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.args=SimpleNamespace(session=str(self.root),source='192.0.2.2',index=10)
  self.corrupt=False;self.change=False;self.fail=False
 def remote(self,cmd,**kw):
  subprocess.run(['bash','-n'],input=cmd.encode(),check=True)
  if 'GUI_IDENTITY' in cmd:raw=b'sound\nGUI_IDENTITY\nmac\nboot\n'
  elif 'cat /proc/mtd' in cmd:raw=b'dev: size erasesize name\nmtd0: 00000004 00010000 "boot"\nmtd1: 00000004 00010000 "data"\n'
  elif 'sha256sum /dev/' in cmd:
   if self.fail:raise subprocess.TimeoutExpired(['ssh'],240)
   blob=b'1234';raw=b.hashlib.sha256(blob).hexdigest().encode()+b'  /dev/mtd\n'+(b'bad!' if self.corrupt else blob)
  elif 'overlay.tar' in cmd:
   out=io.BytesIO()
   with tarfile.open(fileobj=out,mode='w') as t:
    m=tarfile.TarInfo('./upper/etc');m.type=tarfile.DIRTYPE;t.addfile(m)
   blob=out.getvalue();raw=b.hashlib.sha256(blob).hexdigest().encode()+b'  overlay.tar\n'+blob
  else:raw=b'changed\n' if self.change else b'sound\n'
  return SimpleNamespace(stdout=raw)
 def run_backup(self):b.backup(self.args,self.remote,'set -eu\n','echo sound\n',lambda s:None)
 def test_verified_backup_and_no_overwrite(self):
  self.run_backup();self.run_backup();folders=list(self.root.iterdir());self.assertEqual(len(folders),2)
  for folder in folders:
   proof=json.loads((folder/'verified.json').read_text());self.assertEqual(len(proof['files']),3)
   for n,h in proof['files'].items():self.assertEqual(b.hashlib.sha256((folder/n).read_bytes()).hexdigest(),h)
 def test_bad_transfer_has_no_verified_marker(self):
  self.corrupt=True
  with self.assertRaises(ValueError):self.run_backup()
  self.assertEqual(list(self.root.rglob('verified.json')),[])
 def test_changed_state_has_no_verified_marker(self):
  self.change=True
  with self.assertRaises(ValueError):self.run_backup()
  self.assertEqual(list(self.root.rglob('verified.json')),[])
 def test_interruption_has_no_verified_marker(self):
  self.fail=True
  with self.assertRaises(subprocess.TimeoutExpired):self.run_backup()
  self.assertEqual(list(self.root.rglob('verified.json')),[])
if __name__=='__main__':unittest.main()
