#!/usr/bin/env python3
"""TC-135: complete closure, pins, ABI and refusal before publication."""
import importlib.util,json,pathlib,sys,tempfile
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from schoolbell_ipk import read,sha,closure,dependencies

def module(name,file):
 s=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
builder=module('package_builder','scripts/build-schoolbell.py');bundle=module('bundle_builder','scripts/build-schoolbell-bundle.py')
def reject(call):
 try:call()
 except (ValueError,KeyError):return
 raise AssertionError('expected refusal')
lock=json.loads((ROOT/'packaging/offline/openwrt-19.07.9-mipsel_24kc.json').read_text())
metas={x['name']:{'Version':x['version'],'Depends':x['depends']}for x in lock['packages']};closure(metas,lock['firmware'])
reject(lambda:closure(metas,{'libc':'1.1.24-2','kernel':'wrong'}))
reject(lambda:dependencies('a | b'))
with tempfile.TemporaryDirectory()as tmp:
 root=pathlib.Path(tmp);cache=root/'cache';cache.mkdir();p=builder.build(root)
 def ipk(name,version,arch,depends='',files=None):
  path=root/(name+'_'+version+'_'+arch+'.ipk')
  control=('Package: '+name+'\nVersion: '+version+'\nArchitecture: '+arch+'\nDepends: '+depends+'\n').encode()
  path.write_bytes(builder.tar_bytes({'debian-binary':(b'2.0\n',0o644),'control.tar.gz':(builder.tar_bytes({'control':(control,0o644)}),0o644),'data.tar.gz':(builder.tar_bytes(files or {}),0o644)}));return path
 # Real dependency declarations, harmless fixture payloads; no network in CI.
 _,_,_=read(p)
 roots=[x[0] for x in dependencies(read(p)[0]['Depends']) if x[0]!='modbus-schoolbell-clock']+['libgcc1','liblua5.1.5']
 pins=[]
 for name in roots:
  f=ipk(name,'1','all');dest=cache/f.name;dest.write_bytes(f.read_bytes())
  pins.append({'name':name,'version':'1','architecture':'all','filename':f.name,'url':'https://downloads.openwrt.org/releases/19.07.9/fixture','sha256':sha(f),'bytes':f.stat().st_size,'depends':'','license':'fixture'})
 config=root/'lock.json';config.write_text(json.dumps({'format':1,'openwrt':'19.07.9','target':'ramips/mt76x8','architecture':'mipsel_24kc','firmware':{'libc':'1','kernel':'fixture'},'packages':pins}))
 elf=b'\x7fELF\x01\x01\x01'+b'\0'*11+b'\x08\x00'+b'fixture'
 native=ipk('modbus-schoolbell-clock','1.0.0','mipsel_24kc','libc, libgcc1, liblua5.1.5',{'usr/lib/lua/schoolbell/clock_linux.so':(elf,0o644)})
 core=ipk('modbus-rtu-core','0.4.0','all','lua, luci-lib-jsonc')
 def run(out,n=native):return bundle.build(config,p,n,core,cache,root/out)
 standalone=bundle.build(config,p,native,None,cache,root/'standalone')
 assert len(standalone['packages'])==len(pins)+2
 assert all(x['role']!='core' for x in standalone['packages'])
 result=run('ok');assert len(result['packages'])==len(pins)+3
 assert (root/'ok/SHA256SUMS').exists() and result['hardware_validated'] is False
 bad=ipk('modbus-schoolbell-clock','1.0.0','x86_64','',{'usr/lib/lua/schoolbell/clock_linux.so':(elf,0o644)})
 reject(lambda:run('bad-arch',bad));assert not(root/'bad-arch').exists()
 bad=ipk('modbus-schoolbell-clock','2.0.0','mipsel_24kc','',{'usr/lib/lua/schoolbell/clock_linux.so':(elf,0o644)})
 reject(lambda:run('bad-version',bad));assert not(root/'bad-version').exists()
 bad=ipk('modbus-schoolbell-clock','1.0.0','mipsel_24kc','',{'usr/lib/lua/schoolbell/clock_linux.so':(b'not a MIPS ELF',0o644)})
 reject(lambda:run('bad-elf',bad));assert not(root/'bad-elf').exists()
 # Restore the fixture native after the same filename was deliberately overwritten.
 native=ipk('modbus-schoolbell-clock','1.0.0','mipsel_24kc','libc, libgcc1, liblua5.1.5',{'usr/lib/lua/schoolbell/clock_linux.so':(elf,0o644)})
 with patch.object(bundle.shutil,'copyfile',side_effect=OSError('injected copy failure')):
  try:run('copy-failed')
  except OSError:pass
  else:raise AssertionError('expected copy failure')
 assert not(root/'copy-failed').exists() and not list(root.glob('.schoolbell-bundle-*'))
 victim=cache/pins[0]['filename'];victim.write_bytes(b'corrupt')
 reject(lambda:run('bad-sha'));assert not(root/'bad-sha').exists()
 victim.unlink();reject(lambda:run('missing'));assert not(root/'missing').exists()
print('PASS offline dependency closure, exact native version, architecture, hashes and no-network cache failures')
