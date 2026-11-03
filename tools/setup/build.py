"""Assemble an offline Windows x64 kit using verified local inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
IMAGE_SHA = 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'
PYTHON_SHA = '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b'
NAME = 'schoolbell-5.1.100-mr3020-eu-v3.30-win11-x64'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def build(bundle, image, runtime, dest):
    if digest(image)!=IMAGE_SHA or digest(runtime)!=PYTHON_SHA:
        raise ValueError('Unexpected recovery image or embedded Python')
    rows=json.loads((bundle/'manifest.json').read_bytes())['packages']
    versions={r['name']:r['version'] for r in rows}
    if len(versions)!=35 or versions.get('modbus-schoolbell')!='5.1.100' or versions.get('modbus-schoolbell-clock')!='1.0.0':
        raise ValueError('Expected standalone 5.1.100 bundle')
    for row in rows:
        file=bundle/row['file']
        if file.parent!=bundle or digest(file)!=row['sha256']:
            raise ValueError('Invalid package: '+row['file'])
    dest.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest) as temporary:
        root=Path(temporary)/NAME
        (root/'firmware').mkdir(parents=True)
        shutil.copyfile(image,root/'firmware/tp_recovery.bin')
        with zipfile.ZipFile(runtime) as z:z.extractall(root/'python')
        shutil.copytree(bundle,root/'bundle')
        for name in ['README.md','Setup.cmd','Setup.ps1','install.py','tftp_server.py']:
            shutil.copyfile(HERE/name,root/name)
        files=sorted(p for p in root.rglob('*') if p.is_file())
        sums=''.join(digest(p)+'  '+p.relative_to(root).as_posix()+'\n' for p in files)
        (root/'SHA256SUMS').write_bytes(sums.encode())
        archive=Path(temporary)/(NAME+'.zip')
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
            for p in files+[root/'SHA256SUMS']:z.write(p,NAME+'/'+p.relative_to(root).as_posix())
        archive.replace(dest/archive.name)
        (dest/(archive.name+'.sha256')).write_text(digest(dest/archive.name)+'  '+archive.name+'\n')
        print(dest/archive.name)

if __name__=='__main__':
    cli=argparse.ArgumentParser(description=__doc__)
    for key in ('bundle','image','runtime'):cli.add_argument('--'+key,required=True,type=Path)
    cli.add_argument('--dest',type=Path,default=HERE/'dist')
    build(**vars(cli.parse_args()))
