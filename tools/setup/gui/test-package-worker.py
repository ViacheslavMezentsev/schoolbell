import hashlib, importlib.util, io, json, os, subprocess, tarfile, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
real_run=subprocess.run
spec=importlib.util.spec_from_file_location('worker',Path(__file__).with_name('package_worker.py'))
w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
class WorkerTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.version='5.1.124';self.writes=0;self.sound='-20\nfalse\nfalse';self.fail_write=False
  self.manifest={}
  for kind,version in [('package','5.1.127'),('rollback','5.1.124')]:
   name='modbus-schoolbell_'+version+'_all.ipk';(self.root/name).write_bytes(kind.encode())
   self.manifest[kind]={'file':name,'version':version,'sha256':w.digest(self.root/name)}
  (self.root/'payload.json').write_text(json.dumps(self.manifest))
  buf=io.BytesIO()
  with tarfile.open(fileobj=buf,mode='w') as tar:
   directory=tarfile.TarInfo('./upper/etc/schoolbell-editor');directory.type=tarfile.DIRTYPE;tar.addfile(directory)
   data=b'{}';info=tarfile.TarInfo('./upper/etc/schoolbell-editor/sound-control.json');info.size=len(data);tar.addfile(info,io.BytesIO(data))
  self.backup=buf.getvalue()
  self.args=SimpleNamespace(action='prepare',source='192.0.2.2',index=10,session=str(self.root/'session'))
  for patcher in [patch.object(w,'__file__',str(self.root/'package_worker.py')),patch.object(w,'route'),patch.object(w.subprocess,'run',side_effect=self.remote),patch.dict(os.environ,{'LOCALAPPDATA':str(self.root)}),patch.object(w,'emit')]:
   patcher.start();self.addCleanup(patcher.stop)
 def remote(self,argv,**kw):
  command=argv[-1]
  import shutil
  if shutil.which('bash'): real_run(['bash','-n'],input=command.encode(),check=True)
  if 'GUI_VERSION_PROBE' in command:
   return SimpleNamespace(stdout=(self.version+'\n').encode())
  if 'GUI_CURRENT_VERIFIED' in command:
   if self.sound!='-20\nfalse\nfalse':raise subprocess.CalledProcessError(1,argv)
   return SimpleNamespace(stdout=b'GUI_CURRENT_VERIFIED\n')
  if 'backup.tar' in command:
   if self.version!='5.1.124':raise subprocess.CalledProcessError(1,argv)
   outer=io.BytesIO()
   with tarfile.open(fileobj=outer,mode='w') as tar:
    for name,data in [('overlay.tar',self.backup),('identity.txt',('identity\nboot\n'+self.version+'\n').encode()),('sound.txt',(self.sound+'\n').encode())]:
     info=tarfile.TarInfo(name);info.size=len(data);tar.addfile(info,io.BytesIO(data))
   payload=outer.getvalue();result=hashlib.sha256(payload).hexdigest().encode()+b'  backup.tar\n'+payload
  else:
   if self.sound!='-20\nfalse\nfalse':raise subprocess.CalledProcessError(1,argv)
   if 'opkg install ' in command:
    self.writes+=1
    if self.fail_write:raise subprocess.TimeoutExpired(argv,240)
    self.version='5.1.127'
   if self.version!='5.1.127':raise subprocess.CalledProcessError(1,argv)
   result=b'GUI_RESULT_VERIFIED\n'
  return SimpleNamespace(stdout=result)
 def test_prepare_install_verify_and_no_repeat(self):
  w.run(self.args);self.assertEqual(self.writes,0)
  self.args.action='install';w.run(self.args);self.assertEqual(self.writes,1)
  self.args.action='verify';w.run(self.args);self.assertEqual(self.writes,1)
  self.args.action='install'
  with self.assertRaises(ValueError):w.run(self.args)
 def test_default_sound_without_control_file(self):
  buf=io.BytesIO()
  with tarfile.open(fileobj=buf,mode='w') as tar:
   directory=tarfile.TarInfo('./upper/etc/schoolbell-editor');directory.type=tarfile.DIRTYPE;tar.addfile(directory)
  self.backup=buf.getvalue();w.run(self.args)
  self.assertTrue((Path(self.args.session)/'prepared.json').exists())
 def test_changed_settings_block_install(self):
  w.run(self.args);self.sound='changed';self.args.action='install'
  with self.assertRaises((ValueError,subprocess.CalledProcessError)):w.run(self.args)
  self.assertEqual(self.writes,0)
 def test_corrupt_backup_blocks(self):
  w.run(self.args);(Path(self.args.session)/'overlay.tar').write_bytes(b'bad');self.args.action='install'
  with self.assertRaises((ValueError,subprocess.CalledProcessError)):w.run(self.args)
  self.assertEqual(self.writes,0)
 def test_unknown_outcome_blocks_repeat(self):
  w.run(self.args);self.args.action='install';self.fail_write=True
  with self.assertRaises(subprocess.TimeoutExpired):w.run(self.args)
  with self.assertRaises(ValueError):w.run(self.args)
  self.assertEqual(self.writes,1)
 def test_bad_payload_blocks(self):
  (self.root/self.manifest['package']['file']).write_bytes(b'bad')
  with self.assertRaises(ValueError):w.run(self.args)
 def test_concurrent_operation_blocks(self):
  Path(self.args.session).mkdir();(Path(self.args.session)/'operation.lock').write_text('other')
  with self.assertRaises(FileExistsError):w.run(self.args)
 def test_reprepare_does_not_erase_write_evidence(self):
  w.run(self.args);(Path(self.args.session)/'write-started').write_text('unknown')
  with self.assertRaises(ValueError):w.run(self.args)
  self.assertTrue((Path(self.args.session)/'prepared.json').exists())
 def test_wrong_rollback_version_blocks(self):
  self.version='5.1.123'
  with self.assertRaises(ValueError):w.run(self.args)
 def test_verify_saved_operation_after_bundle_changed(self):
  w.run(self.args);self.args.action='install';w.run(self.args)
  (self.root/'payload.json').write_text('{}')
  self.args.action='verify';w.run(self.args)
  self.args.action='new-session';w.run(self.args)
  self.assertEqual(self.writes,1)
 def test_failed_verification_invalidates_previous_proof(self):
  w.run(self.args);self.args.action='install';w.run(self.args)
  self.sound='changed';self.args.action='verify'
  with self.assertRaises(subprocess.CalledProcessError):w.run(self.args)
  self.assertFalse((Path(self.args.session)/'verified.json').exists())
  self.args.action='new-session'
  with self.assertRaises(FileNotFoundError):w.run(self.args)
 def test_archive_verified_session_preserves_backup(self):
  w.run(self.args);self.args.action='install';w.run(self.args)
  folder=Path(self.args.session);before=(folder/'backup.tar').read_bytes()
  self.args.action='new-session';w.run(self.args)
  history=list((folder.parent/'session-history').iterdir());self.assertEqual(len(history),1)
  self.assertEqual((history[0]/'backup.tar').read_bytes(),before)
  self.assertTrue((history[0]/'write-started').exists())
  self.assertFalse((history[0]/'operation.lock').exists())
  self.assertEqual(list(folder.iterdir()),[])
  self.assertEqual(self.writes,1)
 def test_archive_unknown_write_refused(self):
  w.run(self.args);folder=Path(self.args.session);(folder/'write-started').write_text('unknown')
  self.args.action='new-session'
  with self.assertRaises((ValueError,FileNotFoundError)):w.run(self.args)
  self.assertTrue((folder/'backup.tar').exists())
 def test_archive_stale_proof_refused(self):
  w.run(self.args);self.args.action='install';w.run(self.args)
  folder=Path(self.args.session);(folder/'write-started').write_text('another write')
  self.args.action='new-session'
  with self.assertRaises(ValueError):w.run(self.args)
  self.assertTrue((folder/'prepared.json').exists())
 def test_archive_prepared_session_without_writing(self):
  w.run(self.args);self.args.action='new-session';w.run(self.args)
  self.assertEqual(self.writes,0)
  self.args.action='prepare';w.run(self.args)
  self.assertTrue((Path(self.args.session)/'prepared.json').exists())
 def test_stable_guard_blocks_new_session(self):
  folder=Path(self.args.session);guard=folder.parent/(folder.name+'.guard');guard.write_text('busy')
  self.args.action='new-session'
  with self.assertRaises(FileExistsError):w.run(self.args)
  self.assertTrue(guard.exists())
 def test_archive_corrupt_backup_refused(self):
  w.run(self.args);self.args.action='install';w.run(self.args)
  (Path(self.args.session)/'backup.tar').write_bytes(b'bad')
  self.args.action='new-session'
  with self.assertRaises(ValueError):w.run(self.args)
 def test_current_version_never_writes_or_prepares_install(self):
  self.version='5.1.127';w.run(self.args)
  self.assertEqual(self.writes,0)
  self.assertFalse((Path(self.args.session)/'prepared.json').exists())
  self.assertTrue(any('ALREADY CURRENT.' in str(c) for c in w.emit.call_args_list))
 def test_current_unhealthy_not_success(self):
  self.version='5.1.127';self.sound='changed'
  with self.assertRaises(subprocess.CalledProcessError):w.run(self.args)
  self.assertEqual(self.writes,0)
  self.assertFalse(any('ALREADY CURRENT.' in str(c) for c in w.emit.call_args_list))
if __name__=='__main__':unittest.main()
