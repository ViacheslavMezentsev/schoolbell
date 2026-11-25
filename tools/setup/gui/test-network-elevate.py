from pathlib import Path
import unittest
from unittest.mock import patch
import io,json
import network_elevate
from network_elevate import arguments
class BridgeTests(unittest.TestCase):
 def test_fixed_arguments(self):
  args=arguments('prepare','11111111-1111-4111-8111-111111111111','factory',Path('fixed helper.ps1'))
  self.assertIn('fixed helper.ps1',args);self.assertEqual(args[-1],'11111111-1111-4111-8111-111111111111')
 def test_flash_requires_operation_and_adapter(self):
  with self.assertRaises(ValueError):arguments('flash','11111111-1111-4111-8111-111111111111','factory',Path('fixed.ps1'))
  args=arguments('flash','11111111-1111-4111-8111-111111111111','factory',Path('fixed.ps1'),'22222222-2222-4222-8222-222222222222')
  self.assertIn('-Operation',args)
 def test_reject_code_and_unknown_actions(self):
  for action,guid,profile in [('run','','openwrt'),('prepare','x;whoami','openwrt'),('restore','','unknown')]:
   with self.assertRaises(ValueError):arguments(action,guid,profile,Path('fixed.ps1'))
 def test_restore_does_not_accept_target_override(self):
  self.assertNotIn('-AdapterGuid',arguments('restore','ignored','openwrt',Path('fixed.ps1')))
 def test_uac_outcomes_do_not_report_false_success(self):
  for result,exitcode in [('cancelled',0),('ok',0),('failed',1),('busy',1)]:
   with patch.object(network_elevate.os,'name','nt'),patch.object(network_elevate,'elevate',return_value=result),patch.object(network_elevate,'arguments',return_value=[]),patch.object(network_elevate,'Path') as path,patch('sys.argv',['bridge','restore']),patch('sys.stdout',new_callable=io.StringIO) as output:
    code=network_elevate.main();self.assertEqual(code,exitcode);self.assertEqual(json.loads(output.getvalue())['helper_result'],result)
if __name__=='__main__' :unittest.main()
