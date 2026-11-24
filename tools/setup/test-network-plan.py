import copy
import unittest
from network_plan import plan

GUID='11111111-1111-4111-8111-111111111111'
def snapshot():
 return dict(schema=1,pending_restore=False,adapters=[dict(guid=GUID,index=7,name='USB Ethernet',physical=True,usb=True,dhcp=True,link_up=True,media='ethernet',addresses=[])],routes=[],udp_ports=[])
class NetworkPlanTests(unittest.TestCase):
 def run_plan(self,s,profile='openwrt'):return plan(s,GUID,profile,'MR3020 EU V3.30')
 def test_profiles_no_ip_and_no_mutation(self):
  s=snapshot();before=copy.deepcopy(s)
  for profile in ('openwrt','factory'):
   p=self.run_plan(s,profile);self.assertTrue(p['eligible']);self.assertFalse(p['ready']);self.assertFalse(p['image']['verified']);self.assertEqual(p['image']['size'],8126464)
  self.assertEqual(s,before)
 def test_required_adapter_flags(self):
  for key in ('physical','usb','dhcp','link_up'):
   s=snapshot();s['adapters'][0][key]=False;self.assertFalse(self.run_plan(s)['eligible'])
 def test_manual_address(self):
  s=snapshot();s['adapters'][0]['addresses']=[dict(ip='192.0.2.7',origin='manual')]
  self.assertIn('manual-address',self.run_plan(s)['blockers'])
 def test_pending_and_ports(self):
  s=snapshot();s['pending_restore']=True;s['udp_ports']=[1069]
  self.assertEqual(set(self.run_plan(s)['blockers']),{'pending-restore','tftp-port-busy'})
 def test_vpn_gateway_not_blanket_rejected(self):
  s=snapshot();s['routes']=[dict(prefix='192.168.1.0/24',next_hop='192.0.2.1',index=9)]
  p=self.run_plan(s);self.assertTrue(p['eligible']);self.assertIn('gateway-route-recheck',p['warnings'])
 def test_competing_routes(self):
  for prefix,hop in [('192.168.1.0/24','0.0.0.0'),('192.168.0.2/32','192.0.2.1')]:
   s=snapshot();s['routes']=[dict(prefix=prefix,next_hop=hop,index=9)]
   self.assertIn('conflicting-route',self.run_plan(s)['blockers'])
 def test_default_route_allowed(self):
  s=snapshot();s['routes']=[dict(prefix='0.0.0.0/0',next_hop='192.0.2.1',index=9)]
  self.assertTrue(self.run_plan(s)['eligible'])
 def test_identity_and_unknown_profile(self):
  s=snapshot();s['adapters'].append(copy.deepcopy(s['adapters'][0]))
  with self.assertRaises(ValueError):self.run_plan(s)
  with self.assertRaises(ValueError):self.run_plan(snapshot(),'unknown')
  with self.assertRaises(ValueError):plan(snapshot(),GUID,'factory','MR3020 v3')
 def test_reserved_address_and_fingerprint(self):
  s=snapshot();old=self.run_plan(s)['snapshot_sha256'];s['adapters'][0]['addresses']=[dict(ip='192.168.0.225',origin='dhcp')]
  p=self.run_plan(s);self.assertIn('reserved-address-in-use',p['blockers']);self.assertNotEqual(old,p['snapshot_sha256'])
 def test_missing_or_invalid_data(self):
  for key in ('dhcp','link_up'):
   s=snapshot();del s['adapters'][0][key]
   with self.assertRaises(ValueError):self.run_plan(s)
  s=snapshot();s['routes']=[dict(prefix='bad',next_hop='0.0.0.0',index=9)]
  with self.assertRaises(ValueError):self.run_plan(s)

if __name__=='__main__':unittest.main()
