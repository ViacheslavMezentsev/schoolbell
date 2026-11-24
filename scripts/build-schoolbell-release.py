#!/usr/bin/env python3
"""Package a verified offline directory into a deterministic release candidate. No network/device access."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
from schoolbell_ipk import read, sha, closure
from license_materials import verify_package

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ('19.07.9', 'ramips/mt76x8', 'mipsel_24kc')

def safe_name(name):
    return (isinstance(name, str) and bool(re.fullmatch(r'[A-Za-z0-9_./+-]+', name))
            and not name.startswith('/') and all(x not in ('', '.', '..') for x in name.split('/')))

def checked_bundle(root):
    if root.is_symlink():
        raise ValueError('Symlink bundle')
    files = {}
    for path in root.rglob('*'):
        if path.is_symlink():
            raise ValueError('Symlink input')
        if path.is_file():
            name = path.relative_to(root).as_posix()
            if not safe_name(name):
                raise ValueError('Unsafe input path')
            files[name] = path
    sums = {}
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  (.+)', line)
        if not match or not safe_name(match[2]) or match[2] in sums:
            raise ValueError('Invalid checksum list')
        sums[match[2]] = match[1]
    if set(sums) != set(files) - {'SHA256SUMS'}:
        raise ValueError('Unlisted or missing bundle files')
    for name, digest in sums.items():
        if sha(files[name]) != digest:
            raise ValueError('Damaged bundle: ' + name)
    doc = json.loads((root / 'manifest.json').read_bytes())
    if tuple(doc.get(k) for k in ('openwrt', 'target', 'architecture')) != PROFILE:
        raise ValueError('Unsupported runtime')
    lock = json.loads((ROOT / 'packaging/offline/openwrt-19.07.9-mipsel_24kc.json').read_bytes())
    if json.loads((root / 'dependencies.lock.json').read_bytes()) != lock:
        raise ValueError('Dependency lock mismatch')
    if not re.fullmatch(r'[0-9a-f]{40}', doc.get('source_commit', '')) or not isinstance(doc.get('source_dirty'), bool):
        raise ValueError('Missing input provenance')
    if doc.get('firmware') != lock['firmware']:
        raise ValueError('Wrong kernel/libc ABI')
    pins = {r['name']: r for r in lock['packages']}
    rows = doc['packages']; metas = {}; names = set(); paths = set()
    for row in rows:
        name, filename = row['name'], row['file']
        if not safe_name(filename) or '/' in filename or not filename.endswith('.ipk') or filename in paths or name in names:
            raise ValueError('Duplicate/unsafe package')
        names.add(name); paths.add(filename)
        path = root / filename
        if sha(path) != row['sha256'] or path.stat().st_size != row['bytes']:
            raise ValueError('Package digest/size mismatch')
        meta, control, payload = read(path)
        if name == "modbus-schoolbell":
            verify_package(payload, "schoolbell")
            if not {"preinst", "postinst", "prerm"} <= set(control) or "usr/sbin/schoolbell-auto" not in payload:
                raise ValueError("Incomplete Schoolbell package")
        if name == "modbus-schoolbell-clock":
            verify_package(payload, "native")
            elf = payload.get("usr/lib/lua/schoolbell/clock_linux.so", (b"", 0))[0]
            if meta["Architecture"] != PROFILE[2] or meta["Version"] != "1.0.0" or elf[:7] != b"\x7fELF\x01\x01\x01" or elf[18:20] != b"\x08\x00":
                raise ValueError("Invalid native clock package")
        if any(meta.get(k) != row[v] for k,v in [('Package','name'),('Version','version'),('Architecture','architecture')]):
            raise ValueError('IPK metadata mismatch')
        if meta.get('Depends', '') != row['depends']:
            raise ValueError('Dependency metadata mismatch')
        if row['architecture'] not in ('all', PROFILE[2]):
            raise ValueError('Wrong package architecture')
        if name in pins and (row['sha256'] != pins[name]['sha256'] or row['version'] != pins[name]['version']):
            raise ValueError('Unpinned dependency')
        metas[name] = meta
    if names != set(pins) | {'modbus-schoolbell', 'modbus-schoolbell-clock'}:
        raise ValueError('Incomplete/extra package set')
    if {n for n in files if n.endswith('.ipk')} != paths:
        raise ValueError('Unlisted package')
    closure(metas, doc['firmware'])
    version = metas['modbus-schoolbell']['Version']
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Invalid project version')
    return doc, files, version

def build(bundle, out, candidate=False):
    doc, files, version = checked_bundle(Path(bundle))
    commit = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty = bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=ROOT))
    json.loads(files['licenses/DEPENDENCIES.json'].read_bytes())
    if not candidate:
        # Explicitly closed until license, audio and hardware release evidence is implemented.
        raise ValueError('Public release gate is not implemented; use --candidate for local validation only')
    notes = ROOT / ('docs/releases/v' + version + '.md')
    if not notes.is_file():
        raise ValueError('Missing release notes for package version')
    manifest = copy.deepcopy(doc)
    manifest.update(format=1, kind='schoolbell-package-bundle', version=version, tag='v'+version,
                    status='candidate', distribution_cleared=False,
                    assembly_commit=commit, assembly_dirty=dirty,
                    wizard={'minimum_version':'0.1.0','bundle_format':1,'integration':'pending'},
                    supported_boards=['tplink,tl-mr3020-v3'],
                    tested_hardware_revisions=['TL-MR3020 EU v3.30'],
                    manual_installation='pending-acceptance',
                    manual_installer={'entrypoint':'scripts/install.py','modes':['fresh'],'hardware_validated':False},
                    hardware_validated=False)
    entries = {}
    for row in manifest['packages']:
        old = row['file']; row['file'] = 'packages/' + old
        entries[row['file']] = files[old].read_bytes()
    for name, path in files.items():
        if name.startswith('licenses/'):
            entries[name] = path.read_bytes()
    entries['dependencies.lock.json'] = files['dependencies.lock.json'].read_bytes()
    entries['input-manifest.json'] = files['manifest.json'].read_bytes()
    entries['RELEASE_NOTES.md'] = notes.read_bytes()
    for name in ('README.md','README.en.md','check.sh','verify.sh','snapshot.sh','plan.py','install.py'):
        target = 'scripts/'+name if name.endswith(('.sh','.py')) else name
        entries[target] = (ROOT/'packaging/release'/name).read_bytes()
    entries['scripts/fresh_install.py'] = (ROOT/'tools/setup/gui/fresh_install.py').read_bytes()
    entries['scripts/schoolbell_ipk.py'] = (ROOT/'scripts/schoolbell_ipk.py').read_bytes()
    entries['packages.tsv'] = ''.join(r['name']+'\t'+r['version']+'\t'+r['file']+'\n' for r in manifest['packages']).encode()
    entries['manifest.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    entries['SHA256SUMS'] = ''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in sorted(entries.items())).encode()
    prefix = 'schoolbell-v'+version
    filename = prefix+'-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip'
    out = Path(out)
    if out.exists():
        raise ValueError('Output must be a new directory')
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.schoolbell-release-',dir=out.parent) as temp:
        stage=Path(temp)/'result';stage.mkdir()
        archive=stage/filename
        with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for name,data in sorted(entries.items()):
                info=zipfile.ZipInfo(prefix+'/'+name,date_time=(1980,1,1,0,0,0))
                info.create_system=3;info.external_attr=(0o100755 if name.endswith('.sh') else 0o100644)<<16
                info.compress_type=zipfile.ZIP_DEFLATED
                z.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
        (stage/'SHA256SUMS').write_text(sha(archive)+'  '+filename+'\n')
        stage.rename(out)
    print(out/filename)
    return out/filename

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    parser.add_argument('--candidate',action='store_true',help='local candidate only; not distribution clearance')
    args=parser.parse_args()
    build(args.bundle,args.out,args.candidate)
