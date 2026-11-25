#!/usr/bin/env python3
"""Allowlisted portable wizard archive; local only, no device or publication."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'tools/setup/gui'
VENDOR = ROOT / 'tools/setup/vendor'
PYTHON_SHA = '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b'
OPENWRT_SHA = 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'
WORKERS = ('network_worker.py network_snapshot.ps1 network_helper.ps1 NetworkHelperCore.ps1 '
           'network_elevate.py flash_worker.py FlashHelperCore.ps1 HelperJob.cs worker_job.py '
           'package_worker.py session_lock.py operation_protocol.py fresh_install.py '
           'device_backup.py zip_worker.py wizard-version.txt').split()
SOURCES = {name: GUI/name for name in WORKERS}
SOURCES.update({name: ROOT/'tools/setup'/name for name in ('network_plan.py','firmware.py','tftp_server.py')})
SOURCES.update({'zip-runtime/'+name: ROOT/'packaging/release'/name for name in ('install.py','plan.py')})
SOURCES['zip-runtime/schoolbell_ipk.py'] = ROOT/'scripts/schoolbell_ipk.py'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read_regular(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError('Missing or linked input: '+path.name)
    # Reject linked parents as well, even when they point back into the build.
    if any(parent.is_symlink() for parent in path.parents):
        raise ValueError('Linked input directory')
    return path.read_bytes()

def collect(build):
    version = (GUI/'wizard-version.txt').read_text().strip()
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Invalid wizard version')
    entries = {}
    for name, source in SOURCES.items():
        data = read_regular(build/name)
        if data != source.read_bytes():
            raise ValueError('Stale deployed source: '+name)
        entries[name] = data
    entries['schoolbell-setup-wizard.exe'] = read_regular(build/'schoolbell-setup-wizard.exe')
    if not entries['schoolbell-setup-wizard.exe'].startswith(b'MZ'):
        raise ValueError('Expected Windows executable')
    image = read_regular(build/'firmware/tp_recovery.bin')
    if digest(image) != OPENWRT_SHA:
        raise ValueError('Unpinned recovery image')
    entries['firmware/tp_recovery.bin'] = image
    runtime = (VENDOR/'python-3.11.9-embed-amd64.zip').read_bytes()
    if digest(runtime) != PYTHON_SHA:
        raise ValueError('Unpinned Python runtime')
    # Reconstruct exact upstream runtime instead of archiving a used Python directory.
    with zipfile.ZipFile(io.BytesIO(runtime)) as archive:
        for item in archive.infolist():
            if item.is_dir():
                continue
            name = item.filename
            if '/' in name or '\\' in name or name in ('.','..'):
                raise ValueError('Unexpected pinned runtime layout')
            data = archive.read(item)
            if name == 'python311._pth':
                data = data.rstrip(b'\r\n') + b'\r\n..\r\n'
            entries['python/'+name] = data
    for lang in ('md','en.md'):
        entries['README.'+lang] = (ROOT/'packaging/wizard'/('README.'+lang)).read_bytes()
    entries['licenses/PROJECT-LICENSE'] = (ROOT/'LICENSE').read_bytes()
    entries['licenses/OPEN-ITEMS.md'] = (ROOT/'docs/LICENSE_AUDIT.md').read_bytes()
    entries['licenses/UPSTREAM.md'] = (ROOT/'packaging/wizard/UPSTREAM.md').read_bytes()
    return version, entries

def build_archive(build, out):
    build, out = Path(build).resolve(), Path(out)
    if out.exists():
        raise ValueError('Output must be a new directory')
    version, entries = collect(build)
    receipt = json.loads(read_regular(build/'build-receipt.json'))
    if receipt.get('version') != version or receipt.get('exe_sha256') != digest(entries['schoolbell-setup-wizard.exe']):
        raise ValueError('EXE build receipt mismatch')
    if receipt.get('firmware_check') != 'passed' or receipt.get('system_dlls_only') is not True:
        raise ValueError('Missing binary checks')
    entries['build-receipt.json'] = (json.dumps(receipt,indent=2)+'\n').encode()
    commit = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git','status','--porcelain'], cwd=ROOT))
    manifest = {'format':1, 'kind':'schoolbell-setup-wizard', 'version':version,
                'platform':'windows', 'architecture':'x86_64', 'status':'prerelease',
                'source_commit':commit, 'source_dirty':dirty,
                'supported_hardware':['TP-Link TL-MR3020 EU v3.30'],
                'package_bundle_format':1, 'embedded_firmware':['OpenWrt 19.07.9','OEM Build250625'],
                'prerequisites':['Windows 11 x64','PowerShell 7','Windows OpenSSH Client'],
                'distribution_review':{'complete':False,'blocking':False},
                'hardware_validated':False, 'automatic_publication':False,
                'files':{name:digest(data) for name,data in sorted(entries.items())}}
    entries['manifest.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    entries['SHA256SUMS'] = ''.join(digest(data)+'  '+name+'\n' for name,data in sorted(entries.items())).encode()
    prefix = 'schoolbell-setup-wizard-v'+version+'-windows-x86_64'
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.wizard-release-',dir=out.parent) as temp:
        stage = Path(temp)/'result'; stage.mkdir()
        archive = stage/(prefix+'.zip')
        with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for name,data in sorted(entries.items()):
                info = zipfile.ZipInfo(prefix+'/'+name, date_time=(1980,1,1,0,0,0))
                info.create_system=3; info.external_attr=0o100644<<16
                z.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
        (stage/'SHA256SUMS').write_text(digest(archive.read_bytes())+'  '+archive.name+'\n')
        stage.rename(out)
    print(out/archive.name)
    return out/archive.name

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    build_archive(args.build,args.out)
