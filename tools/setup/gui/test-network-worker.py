import copy
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import importlib.util
import unittest
from network_worker import evaluate
spec=importlib.util.spec_from_file_location('fixtures',Path(__file__).resolve().parents[1]/'test-network-plan.py')
fixtures=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixtures)

class WorkerTests(unittest.TestCase):
 def test_inventory_includes_disconnected_adapter_without_ip(self):
  s=fixtures.snapshot();s['adapters'][0]['link_up']=False
  r=evaluate(s);self.assertEqual(len(r['choices']),1);self.assertIsNone(r['plan'])
 def test_fresh_snapshot_changes_result(self):
  s=fixtures.snapshot();before=copy.deepcopy(s)
  good=evaluate(s,fixtures.GUID,'factory','MR3020 EU V3.30');self.assertTrue(good['plan']['eligible'])
  self.assertEqual(s,before)
  s['udp_ports']=[69]
  bad=evaluate(s,fixtures.GUID,'factory','MR3020 EU V3.30');self.assertFalse(bad['plan']['eligible']);self.assertIn('UDP 69',bad['message'])
 def test_changed_identity_and_unconfirmed_model_rejected(self):
  with self.assertRaises(ValueError):evaluate(fixtures.snapshot(),fixtures.GUID,'openwrt','')
  s=fixtures.snapshot();s['adapters']=[]
  with self.assertRaises(ValueError):evaluate(s,fixtures.GUID,'openwrt','MR3020 EU V3.30')

if __name__=='__main__':unittest.main()
