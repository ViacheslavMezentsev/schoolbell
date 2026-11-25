import importlib.util, json, hashlib, socket, struct, sys, tempfile, threading, unittest
from pathlib import Path
from unittest.mock import patch, Mock
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
import flash_worker as worker
from tftp_server import serve, transfer

class FlashTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
  self.id='11111111-1111-4111-8111-111111111111';self.payload=b'firmware'*128
  self.profiles={p:(p,hashlib.sha256(self.payload).hexdigest(),p) for p in ('openwrt','factory')}
 def test_receipt_retries_transient_windows_sharing_conflict(self):
  path=self.root/'receipt.json';replace=worker.os.replace;calls=[]
  def contended(src,dst):
   calls.append(1)
   if len(calls)<4:raise PermissionError('Windows reader holds receipt')
   replace(src,dst)
  with patch.object(worker.os,'replace',side_effect=contended),patch.object(worker.time,'sleep'):
   worker.write(path,{'n':7})
  self.assertEqual(json.loads(path.read_text()),{'n':7});self.assertEqual(len(calls),4)
 def seed(self,profile='openwrt'):
  (self.root/(profile+'.bin')).write_bytes(self.payload)
  worker.write(self.root/'flash-session.json',dict(schema=1,operation=self.id,profile=profile,phase='preparing',possible_write=False,transfer_complete=False,acknowledged=0))
 def receipt(self):return json.loads((self.root/'flash-session.json').read_text())
 def run_profile(self,transport,profile='openwrt'):
  with patch.object(worker,'PROFILES',self.profiles),patch.object(worker,'RECOVERY_BYTES',len(self.payload)):
   worker.run(profile,self.root,self.id,transport)
 def test_both_profiles_use_exact_pinned_bytes(self):
  for profile in self.profiles:
   self.seed(profile)
   def transport(data,event):
    self.assertEqual(data,self.payload);event('ready',0);event('transferring',0)
    self.assertTrue(self.receipt()['possible_write'])
    event('transferred',len(data))
   self.run_profile(transport,profile);self.assertTrue(self.receipt()['transfer_complete'])
 def test_operation_receipts_do_not_overwrite_previous_result(self):
  self.seed()
  def complete(data,event):event('ready',0);event('transferring',0);event('transferred',len(data))
  self.run_profile(complete)
  first=self.root/('flash-'+self.id+'.json');original=first.read_bytes()
  self.assertEqual(json.loads(original),self.receipt())
  self.id='22222222-2222-4222-8222-222222222222';self.seed('factory')
  self.run_profile(complete,'factory')
  self.assertEqual(first.read_bytes(),original)
  self.assertEqual(json.loads((self.root/('flash-'+self.id+'.json')).read_text()),self.receipt())
 def test_gui_transport_uses_three_minute_wait(self):
  self.seed();transport=Mock()
  with patch.object(worker,'serve',transport):self.run_profile(transport)
  self.assertEqual(transport.call_args.kwargs['wait_seconds'],180)
 def test_ready_deadline_and_transfer_clear_countdown(self):
  self.seed()
  def transport(data,event):
   with patch.object(worker.time,'time',return_value=1000):event('ready',0)
   self.assertEqual(self.receipt()['wait_until_ms'],1180000)
   event('transferring',0)
   self.assertEqual(self.receipt()['wait_until_ms'],0)
  self.run_profile(transport)
 def test_bad_hash_never_starts_transport(self):
  self.seed();(self.root/'openwrt.bin').write_bytes(b'bad')
  with self.assertRaises(ValueError):self.run_profile(lambda *a:self.fail('transport started'))
  self.assertFalse(self.receipt()['possible_write'])
 def test_mismatched_operation(self):
  self.seed()
  with self.assertRaises(ValueError):worker.run('openwrt',self.root,'22222222-2222-4222-8222-222222222222',lambda *a:self.fail())
 def test_timeout_and_transfer_failure_are_different(self):
  for started in (False,True):
   self.seed()
   def transport(data,event):
    event('ready',0)
    if started:event('transferring',0)
    raise TimeoutError()
   with self.assertRaises(TimeoutError):self.run_profile(transport)
   self.assertEqual(self.receipt()['phase'],'unknown' if started else 'not-started')
   self.assertFalse(self.receipt()['transfer_complete'])
 def test_wait_cancel_sends_no_data(self):
  events=[]
  with self.assertRaises(InterruptedError):serve(b'x',lambda p,n:events.append(p),bind='127.0.0.1',client='127.0.0.1',port=0,data_port=0,cancelled=lambda:True)
  self.assertEqual(events,['ready'])
 def test_transfer_cancel_stops_before_retry(self):
  packets=[]
  class Sender:
   def sendto(self,packet,peer):packets.append(packet)
   def getsockname(self):return ('127.0.0.1',1)
  with self.assertRaises(InterruptedError):transfer(Sender(),('127.0.0.1',2),self.payload,cancelled=lambda:bool(packets))
  self.assertEqual(len(packets),1)
 def test_no_request_times_out_without_data(self):
  events=[]
  with self.assertRaises(TimeoutError):serve(b'x',lambda p,n:events.append(p),wait_seconds=.01,bind='127.0.0.1',client='127.0.0.1',port=0,data_port=0)
  self.assertEqual(events,['ready','not-started'])
 def test_loopback_rrq_exact_bytes_and_final_empty_packet(self):
  with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
   probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
  ready=threading.Event();events=[];results=[]
  def event(phase,count):
   events.append((phase,count))
   if phase=='ready':ready.set()
  def server():
   try:results.append(serve(self.payload,event,wait_seconds=5,bind='127.0.0.1',client='127.0.0.1',port=port,data_port=0))
   except Exception as e:results.append(e)
  t=threading.Thread(target=server);t.start()
  try:
   self.assertTrue(ready.wait(2))
   with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as client:
    client.bind(('127.0.0.1',0));client.settimeout(.05)
    client.sendto(b'\0\1wrong.bin\0octet\0',('127.0.0.1',port))
    with self.assertRaises(socket.timeout):client.recvfrom(2048)
    client.settimeout(2);client.sendto(b'\0\1tp_recovery.bin\0octet\0',('127.0.0.1',port));received=bytearray()
    while True:
     packet,peer=client.recvfrom(2048);opcode,block=struct.unpack('!HH',packet[:4]);self.assertEqual(opcode,3)
     self.assertIn(('transferring',0),events)
     received.extend(packet[4:]);client.sendto(struct.pack('!HH',4,block),peer)
     if len(packet)<516:break
    self.assertEqual(bytes(received),self.payload)
  finally:t.join(6)
  self.assertFalse(t.is_alive());self.assertEqual(results,[len(self.payload)])
  self.assertEqual(events[-1],('transferred',len(self.payload)))
if __name__=='__main__':unittest.main()
