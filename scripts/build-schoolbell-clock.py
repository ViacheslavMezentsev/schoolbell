#!/usr/bin/env python3
"""Build the optional MR3020 clock dependency directly; never install it."""
import argparse, gzip, hashlib, io, json, os, struct, subprocess, tarfile, tempfile
from pathlib import Path
from license_materials import package_files
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc',required=True);p.add_argument('--include',action='append',required=True)
p.add_argument('--out',type=Path,default=Path('out/schoolbell-clock'))
a=p.parse_args();root=Path(__file__).resolve().parent.parent
a.out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='schoolbell-clock-') as tmp:
 so=Path(tmp)/'clock_linux.so'
 subprocess.run([a.cc,'-std=c99','-Os','-Wall','-Wextra','-Werror','-pedantic','-fPIC','-shared',*['-I'+v for v in a.include],str(root/'src/native/clock_lua.c'),'-lm','-o',str(so)],check=True)
 data=so.read_bytes()
 if data[:7]!=b'\x7fELF\x01\x01\x01' or struct.unpack_from('<H',data,18)[0]!=8:
  raise SystemExit('Expected ELF32 little-endian MIPS, not a host library')
 def archive(files):
  b=io.BytesIO()
  with tarfile.open(fileobj=b,mode='w')as t:
   parents={str(p) for name in files for p in Path(name).parents if str(p)!='.'}
   for name in sorted(parents,key=lambda x:(x.count('/'),x)):
    info=tarfile.TarInfo(name+'/');info.type=tarfile.DIRTYPE;info.mode=0o755;t.addfile(info)
   for name,body in files.items():
    info=tarfile.TarInfo(name);info.size=len(body);info.mode=0o644;t.addfile(info,io.BytesIO(body))
  return gzip.compress(b.getvalue(), mtime=0)
 control=b'Package: modbus-schoolbell-clock\nVersion: 1.0.0\nArchitecture: mipsel_24kc\nDepends: libc, libgcc1, liblua5.1.5\nSection: sound\nPriority: optional\nDescription: Schoolbell Lua 5.1 clock observation and durable reference storage.\n No clock-setting or NTP configuration operations.\n'
 target=a.out/'modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk'
 payload={'usr/lib/lua/schoolbell/clock_linux.so':data}
 payload.update({name: body for name, (body, _) in package_files('native').items()})
 target.write_bytes(archive({'debian-binary':b'2.0\n','control.tar.gz':archive({'control':control}),'data.tar.gz':archive(payload)}))
 manifest={'package':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'module_bytes':len(data),'module_sha256':hashlib.sha256(data).hexdigest(),'architecture':'mipsel_24kc','lua':'5.1','target':'OpenWrt 19.07.9 ramips/mt76x8 musl','installed':False}
 (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(manifest,indent=2))
