import subprocess
import sys
import tempfile
from pathlib import Path
import unittest
from session_lock import lease, marker, recover

class RecoveryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.folder=Path(self.tmp.name)/'session';self.folder.mkdir()
 def test_live_process_blocks_then_crash_releases(self):
  code="from pathlib import Path;from session_lock import lease,marker;import sys,time;f=Path(sys.argv[1]);\nwith lease(f):\n marker(Path(str(f)+'.guard'));print('ready',flush=True);time.sleep(60)"
  p=subprocess.Popen([sys.executable,'-c',code,str(self.folder)],cwd=Path(__file__).parent,stdout=subprocess.PIPE,text=True)
  try:
   self.assertEqual(p.stdout.readline().strip(),'ready')
   with self.assertRaises(ValueError):
    with lease(self.folder): self.fail('concurrent access')
  finally: p.kill();p.wait();p.stdout.close()
  with lease(self.folder):self.assertEqual(recover(self.folder),'error')
  self.assertFalse(Path(str(self.folder)+'.guard').exists())
  self.assertEqual(len(list((self.folder.parent/'recovery-history').glob('*/*'))),1)
 def test_write_marker_and_copies_preserved(self):
  marker(Path(str(self.folder)+'.guard'));marker(self.folder/'operation.lock');marker(self.folder/'zip-session.guard')
  for name in ('write-started','backup.tar','prepared.json'):(self.folder/name).write_bytes(b'evidence')
  with lease(self.folder):self.assertEqual(recover(self.folder),'uncertain')
  for name in ('write-started','backup.tar','prepared.json'):self.assertEqual((self.folder/name).read_bytes(),b'evidence')
  with lease(self.folder):self.assertEqual(recover(self.folder),'uncertain')
 def test_legacy_or_corrupt_markers_remain(self):
  p=Path(str(self.folder)+'.guard')
  for data in ('','1234','{bad','{"format":1}'):
   p.write_text(data)
   with lease(self.folder):
    with self.assertRaises(ValueError):recover(self.folder)
   self.assertEqual(p.read_text(),data)
 def test_partial_recovery_retry(self):
  marker(self.folder/'operation.lock')
  with lease(self.folder):self.assertEqual(recover(self.folder),'error')
  with lease(self.folder):self.assertEqual(recover(self.folder),'error')
 def test_zip_write_is_uncertain(self):
  (self.folder/'zip-session').mkdir();(self.folder/'zip-session/write-started').touch()
  with lease(self.folder):self.assertEqual(recover(self.folder),'uncertain')

if __name__=='__main__':unittest.main()
