#!/usr/bin/env python3
"""Offline preliminary package plan. Never connects, installs or authorizes a write."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode = True
from schoolbell_ipk import read, sha, closure

PROFILE = ('19.07.9', 'ramips/mt76x8', 'mipsel_24kc')
ABI = {'kernel': '4.14.267-1-d92769dc5268e102503ae83fe968a56c', 'libc': '1.1.24-2'}
STOCK = {n: 'git-22.045.73925-36e5c1c-1' for n in
         ('luci-base', 'luci-lib-ip', 'luci-lib-jsonc', 'luci-lib-nixio', 'luci-theme-bootstrap')}
STOCK.update({'libubus-lua': '2021-07-01-38c7fdd8-1', 'libubus20210603': '2021-07-01-38c7fdd8-1'})

def safe(name):
    return bool(re.fullmatch(r'[A-Za-z0-9_./+-]+', name)) and not name.startswith('/') and all(p not in ('', '.', '..') for p in name.split('/'))

def bundle(root):
    root = Path(root)
    if root.is_symlink(): raise ValueError('Symlink bundle')
    files = {}
    for p in root.rglob('*'):
        if p.is_symlink(): raise ValueError('Symlink input')
        if p.is_file(): files[p.relative_to(root).as_posix()] = p
    checks = {}
    for line in (root/'SHA256SUMS').read_text(encoding='utf8').splitlines():
        m = re.fullmatch(r'([0-9a-f]{64})  (.+)', line)
        if not m or not safe(m[2]) or m[2] in checks: raise ValueError('Invalid checksums')
        checks[m[2]] = m[1]
    if set(checks) != set(files)-{'SHA256SUMS'}: raise ValueError('Missing/unlisted file')
    for name, digest in checks.items():
        if sha(files[name]) != digest: raise ValueError('Damaged file: '+name)
    doc = json.loads(files['manifest.json'].read_bytes())
    if doc.get('format') != 1 or doc.get('kind') != 'schoolbell-package-bundle': raise ValueError('Unsupported bundle format')
    if tuple(doc.get(k) for k in ('openwrt','target','architecture')) != PROFILE or doc.get('firmware') != ABI:
        raise ValueError('Unsupported bundle ABI')
    pins = json.loads(files['dependencies.lock.json'].read_bytes())
    if pins['firmware'] != ABI: raise ValueError('Wrong lock ABI')
    locked = {p['name']: p for p in pins['packages']}
    if len(locked) != 33 or len(pins['packages']) != 33: raise ValueError('Incomplete dependency lock')
    rows = []; metas = {}; paths = set()
    for item in doc['packages']:
        item = dict(item); name, path = item['name'], item['file']
        if not re.fullmatch(r'packages/[A-Za-z0-9_.+-]+[.]ipk', path) or path in paths or name in metas: raise ValueError('Duplicate/unsafe package')
        paths.add(path)
        p = files[path]
        if sha(p) != item['sha256'] or p.stat().st_size != item['bytes']: raise ValueError('Wrong package hash/size')
        meta, _, data = read(p)
        for key, field in [('Package','name'),('Version','version'),('Architecture','architecture'),('Depends','depends')]:
            if meta.get(key, '') != item[field]: raise ValueError('Wrong IPK metadata')
        if item['architecture'] not in ('all', PROFILE[2]): raise ValueError('Wrong architecture')
        if name in locked and any(item[k] != locked[name][k] for k in ('version','sha256')): raise ValueError('Wrong pinned dependency')
        # Recompute from payload, never trust a declared low estimate.
        item['payload_blocks_bytes'] = sum((len(raw)+4095)//4096*4096 for raw, _ in data.values())
        metas[name] = meta; rows.append(item)
    if set(metas) != set(locked)|{'modbus-schoolbell','modbus-schoolbell-clock'} or paths != {n for n in files if n.endswith('.ipk')}:
        raise ValueError('Incomplete package set')
    if metas['modbus-schoolbell']['Version'] != doc['version'] or not re.fullmatch(r'[0-9]+[.][0-9]+[.][0-9]+', doc['version']): raise ValueError('Wrong target version')
    if metas['modbus-schoolbell-clock']['Version'] != '1.0.0': raise ValueError('Wrong native version')
    closure(metas, ABI)
    return doc, rows, sha(root/'SHA256SUMS')

def snapshot(raw):
    fields = {}; installed = {}
    for line in raw.splitlines():
        parts = line.split('\t')
        if len(parts) == 3 and parts[0] == 'package':
            name, version = parts[1:]
            if not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', name) or not version or name in installed: raise ValueError('Invalid inventory')
            installed[name] = version
        elif len(parts) == 2 and parts[0] not in fields:
            fields[parts[0]] = parts[1]
        else: raise ValueError('Malformed/duplicate snapshot field')
    required = {'format','board','openwrt','target','architecture','overlay_kib','tmp_kib','pending','data','automatic','complete'}
    if set(fields) != required or fields['format'] != '1' or fields['complete'] != '1': raise ValueError('Incomplete snapshot')
    if fields['board'] != 'tplink,tl-mr3020-v3' or tuple(fields[k] for k in ('openwrt','target','architecture')) != PROFILE: raise ValueError('Unsupported device')
    if any(installed.get(k) != v for k,v in ABI.items()): raise ValueError('Unsupported device ABI')
    if fields['pending'] != '0' or fields['automatic'] != 'off': raise ValueError('Pending write or automatic bells not off')
    if fields['data'] not in ('0','1'): raise ValueError('Invalid data state')
    for k in ('overlay_kib','tmp_kib'):
        if not re.fullmatch(r'[0-9]+', fields[k]): raise ValueError('Invalid space reading')
        fields[k] = int(fields[k])
    return fields, installed

def plan(root, raw):
    doc, rows, digest = bundle(root)
    fields, installed = snapshot(raw)
    old = installed.get('modbus-schoolbell')
    if old not in (None, doc['version']): raise ValueError('Upgrade needs a separately validated rollback package; not supported by this planner')
    if old is None and fields['data'] != '0': raise ValueError('Existing Schoolbell data on fresh device')
    missing = []; retained = []
    for row in rows:
        version = installed.get(row['name'])
        if version is None: missing.append(row)
        elif version not in (row['version'], STOCK.get(row['name'])): raise ValueError('Incompatible installed package: '+row['name'])
        else: retained.append({'name': row['name'], 'version': version})
    if old and missing: raise ValueError('Incomplete current installation; repair is not supported')
    # Re-evaluate dependency closure against retained stock versions too.
    effective = {n: {'Version': v} for n,v in installed.items()}
    for row in rows:
        effective[row['name']] = {'Version': installed.get(row['name'],row['version']), 'Depends': row['depends']}
    closure(effective, ABI)
    flash = (sum(r['payload_blocks_bytes'] for r in missing)+1023)//1024 + (512 if missing else 0)
    ram = (sum(r['bytes'] for r in missing)+1023)//1024 + (4096 if missing else 0)
    if fields['overlay_kib'] < flash or fields['tmp_kib'] < ram: raise ValueError('Insufficient estimated space')
    return dict(format=1, status='preliminary-only', write_authorized=False,
                mode='already-current' if old else 'fresh', version=doc['version'],
                bundle_checksums_sha256=digest, snapshot_sha256=hashlib.sha256(raw.encode()).hexdigest(),
                required_overlay_kib=flash, required_tmp_kib=ram,
                available_overlay_kib=fields['overlay_kib'], available_tmp_kib=fields['tmp_kib'],
                install=[{k:r[k] for k in ('name','version','file','sha256','bytes')} for r in missing],
                retain=retained, remaining=['fresh live checks','verified off-device backup','recovery preparation','explicit installation confirmation','post-install verification'])

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument('--snapshot', type=Path, required=True)
    args = ap.parse_args()
    try:
        print(json.dumps(plan(args.bundle,args.snapshot.read_text(encoding='utf8')),ensure_ascii=False,indent=2))
    except (ValueError, KeyError, TypeError, OSError) as error:
        ap.exit(1, 'PLAN REFUSED: '+str(error)+'\n')
