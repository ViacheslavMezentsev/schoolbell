#!/usr/bin/env python3
"""Build the complete script package from the same payload used for commissioning."""
import argparse, io, os, pathlib, subprocess, tarfile, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def tar_bytes(files):
    out=io.BytesIO()
    with tarfile.open(fileobj=out,mode='w:gz') as t:
        # opkg/libbb extraction does not create omitted parent directories.
        parents={str(p) for name in files for p in pathlib.PurePosixPath(name).parents if str(p)!='.'}
        for name in sorted(parents,key=lambda x:(x.count('/'),x)):
            m=tarfile.TarInfo('./'+name+'/');m.type=tarfile.DIRTYPE;m.mode=0o755;m.mtime=0
            t.addfile(m)
        for name,(data,mode) in sorted(files.items()):
            m=tarfile.TarInfo('./'+name);m.size=len(data);m.mode=mode;m.mtime=0
            t.addfile(m,io.BytesIO(data))
    return out.getvalue()
def build(out,version=None):
    control=(ROOT/'packaging/openwrt/package/CONTROL/control').read_text()
    current=next(x[9:] for x in control.splitlines() if x.startswith('Version: '))
    if version and version!=current: raise ValueError('change source version; payload and IPK must agree')
    with tempfile.TemporaryDirectory() as tmp:
        payload=pathlib.Path(tmp)/'payload.tar'
        subprocess.run(['python3',str(ROOT/'scripts/build-payload.py'),str(payload)],check=True)
        with tarfile.open(payload) as t:
            data={m.name:(t.extractfile(m).read(),m.mode) for m in t if m.isfile()}
    data['usr/share/modbus-schoolbell/media-manifest.json']=((ROOT/'assets/melodies/manifest.json').read_bytes(),0o644)
    source=ROOT/'packaging/openwrt/package'
    for p in (source/'usr').rglob('*'):
        if p.is_file():data[p.relative_to(source).as_posix()]=(p.read_bytes(),0o644)
    controls={p.name:(p.read_bytes(),0o644 if p.name=='control' else 0o755) for p in (source/'CONTROL').iterdir() if p.is_file()}
    installed=sum(len(v[0]) for v in data.values())
    controls['control']=((control+'Installed-Size: '+str(installed)+'\n').encode(),0o644)
    body=tar_bytes({'debian-binary':(b'2.0\n',0o644),'control.tar.gz':(tar_bytes(controls),0o644),'data.tar.gz':(tar_bytes(data),0o644)})
    out=pathlib.Path(out);out.mkdir(parents=True,exist_ok=True)
    path=out/('modbus-schoolbell_'+current+'_all.ipk');path.write_bytes(body)
    print('Built:',path,'payload bytes:',installed);return path
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',default='out');p.add_argument('--version');a=p.parse_args();build(a.out,a.version)
