import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from operation_protocol import Operation, Cancelled

class ProtocolTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.args=SimpleNamespace(action='prepare',operation_id='a'*32,session_id='b'*64,session=str(Path(self.tmp.name)/'session'))
 def row(self,op):return json.loads(op.path.read_text())
 def test_result_not_log(self):
  op=Operation(self.args)
  def job(args):
   print('UNCHANGED VERIFIED. ALREADY CURRENT. UPGRADE VERIFIED.')
   args.phase('preparing');return 'ready'
  with contextlib.redirect_stdout(io.StringIO()):op.execute(self.args,job)
  row=self.row(op);self.assertEqual(row['kind'],'completed');self.assertEqual(row['value'],'ready')
  self.assertEqual(row['operation'],'a'*32);self.assertEqual(row['sequence'],3)
 def test_missing_typed_result_rejected(self):
  op=Operation(self.args)
  with self.assertRaises(ValueError):op.execute(self.args,lambda args:None)
  self.assertEqual(self.row(op)['kind'],'failed')
 def test_wrong_action_result_rejected(self):
  op=Operation(self.args)
  with self.assertRaises(ValueError):op.execute(self.args,lambda args:'done')
 def test_cancel_before_start_no_dispatch(self):
  op=Operation(self.args);op.cancel_path.write_text('cancel')
  with self.assertRaises(Cancelled):op.execute(self.args,lambda args:self.fail('dispatched'))
  self.assertEqual(self.row(op)['kind'],'cancelled')
 def test_cancel_race_before_constructor(self):
  folder=Path(self.args.session).parent/'operations';folder.mkdir()
  (folder/(self.args.operation_id+'.cancel')).write_text('cancel')
  op=Operation(self.args)
  with self.assertRaises(Cancelled):op.execute(self.args,lambda args:self.fail('dispatched'))
 def test_cancel_at_next_checkpoint(self):
  op=Operation(self.args)
  def job(args):
   op.cancel_path.write_text('cancel');args.check_cancel();self.fail('continued')
  with self.assertRaises(Cancelled):op.execute(self.args,job)
 def test_install_is_not_interruptible(self):
  self.args.action='install';op=Operation(self.args);op.cancel_path.write_text('cancel')
  self.assertEqual(op.execute(self.args,lambda args:'done'),'done')
 def test_exception_types_and_no_details(self):
  for number,error in enumerate([ValueError('private'),subprocess.TimeoutExpired('private',1),subprocess.CalledProcessError(255,'private')]):
   self.args.operation_id=str(number)*32;op=Operation(self.args)
   def job(args):raise error
   with self.assertRaises(type(error)):op.execute(self.args,job)
   self.assertEqual(self.row(op)['kind'],'failed');self.assertNotIn('private',op.path.read_text())
 def test_old_id_not_overwritten(self):
  op=Operation(self.args);op.execute(self.args,lambda args:'ready');saved=op.path.read_bytes()
  with self.assertRaises(ValueError):Operation(self.args)
  self.assertEqual(op.path.read_bytes(),saved)
 def test_invalid_identifiers(self):
  self.args.operation_id='../bad'
  with self.assertRaises(ValueError):Operation(self.args)
 def test_cancel_cleanup_releases_worker_lock(self):
  import package_worker
  from unittest.mock import patch
  op=Operation(self.args)
  def cancel(args):raise Cancelled()
  with patch.object(package_worker,'run_core',cancel):
   with self.assertRaises(Cancelled):op.execute(self.args,package_worker.run)
  self.assertFalse((Path(self.args.session)/'operation.lock').exists())
  self.assertFalse(Path(self.args.session+'.guard').exists())

if __name__=='__main__':unittest.main()
