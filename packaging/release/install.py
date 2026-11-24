#!/usr/bin/env python3
"""Host-side ZIP fresh installation. Explicit SSH target; no firmware operations."""
import argparse
from contextlib import contextmanager
import io
import ipaddress
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
from types import SimpleNamespace
import zipfile
sys.dont_write_bytecode = True
import plan
import fresh_install as fresh

MAX_ZIP = 64 * 1024 * 1024
MAX_CONTENT = 128 * 1024 * 1024
MAX_FILES = 512
RECOVERY_SHA = fresh.RECOVERY_SHA
BASE = """set -eu
. /etc/openwrt_release
test "$(id -u)" = 0
test "$(cat /tmp/sysinfo/board_name)" = tplink,tl-mr3020-v3
test "$DISTRIB_RELEASE:$DISTRIB_TARGET:$DISTRIB_ARCH" = 19.07.9:ramips/mt76x8:mipsel_24kc
test "$(opkg status kernel | sed -n 's/^Version: //p')" = 4.14.267-1-d92769dc5268e102503ae83fe968a56c
test "$(opkg status libc | sed -n 's/^Version: //p')" = 1.1.24-2
test ! -e /etc/schoolbell-editor/package.pending
"""
OFF = """lua - <<'LUA'
package.path='/usr/share/schoolbell-editor/lua/?.lua;'..package.path
local a=require('schoolbell.automatic_store')
assert(not a.decode(a.raw()).enabled, 'Automatic bells must be off')
LUA
"""

def write_json(path, data):
    # Exclusive publication: never replace an existing preparation.
    with path.open('x', encoding='utf8') as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.flush(); os.fsync(stream.fileno())

def zip_bytes(path):
    with Path(path).open('rb') as stream: raw = stream.read(MAX_ZIP+1)
    if len(raw)>MAX_ZIP: raise ValueError('ZIP too large')
    return raw

def unpack(raw, destination):
    """Only one bounded, ASCII, case-insensitively unique file tree. No extractall."""
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        infos = archive.infolist()
        if not infos or len(infos)>MAX_FILES: raise ValueError('ZIP entry limit')
        seen=set(); roots=set(); total=0
        for info in infos:
            name=info.filename; mode=info.external_attr>>16
            if not plan.safe(name) or info.is_dir() or name.casefold() in seen or len(name)>240:
                raise ValueError('Unsafe/duplicate ZIP path')
            if any(part.endswith('.') or part.split('.')[0].upper() in
                   {'CON','PRN','AUX','NUL',*(f'COM{i}' for i in range(1,10)),*(f'LPT{i}' for i in range(1,10))}
                   for part in name.split('/')): raise ValueError('Unsafe Windows ZIP path')
            if stat.S_IFMT(mode) not in (0,stat.S_IFREG) or info.flag_bits & 1: raise ValueError('ZIP link/type/encryption')
            if info.file_size>16*1024*1024: raise ValueError('ZIP member too large')
            total+=info.file_size
            if total>MAX_CONTENT: raise ValueError('ZIP expansion limit')
            seen.add(name.casefold()); roots.add(name.split('/')[0])
        if len(roots)!=1 or not re.fullmatch(r'schoolbell-v[0-9]+[.][0-9]+[.][0-9]+',next(iter(roots))):
            raise ValueError('ZIP root/version')
        destination.mkdir(mode=0o700)
        for info in infos:
            path=destination/info.filename
            path.parent.mkdir(parents=True,exist_ok=True)
            with archive.open(info) as source, path.open('xb') as output:
                count=0
                while True:
                    chunk=source.read(65536)
                    if not chunk: break
                    count+=len(chunk)
                    if count>info.file_size: raise ValueError('ZIP size mismatch')
                    output.write(chunk)
                if count!=info.file_size: raise ValueError('Truncated ZIP')
    root=destination/next(iter(roots))
    doc,rows,digest=plan.bundle(root)
    if root.name!='schoolbell-v'+doc['version']: raise ValueError('ZIP root differs from manifest')
    return root,doc,rows,digest

@contextmanager
def guard(session, create=False):
    session=Path(session).absolute()
    runtime_root=Path(__file__).resolve().parents[1]
    if (runtime_root/'manifest.json').is_file() and (session==runtime_root or runtime_root in session.parents):
        raise ValueError('Keep the session outside the extracted bundle')
    if session.is_symlink(): raise ValueError('Symlink session')
    session.parent.mkdir(parents=True,exist_ok=True)
    lock=session.parent/(session.name+'.guard')
    fd=os.open(lock,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    os.close(fd)
    try:
        if create: session.mkdir(mode=0o700)
        elif not session.is_dir(): raise ValueError('Missing session')
        yield session
    finally: lock.unlink()

class SSH:
    def __init__(self, connection):
        self.connection=connection
        for name in ('host','source'): ipaddress.IPv4Address(connection[name])
        known=Path(connection['known_hosts'])
        if not known.is_absolute() or not known.is_file() or any(c in str(known) for c in '\n\r"'):
            raise ValueError('Existing absolute known-hosts path required')
        if plan.sha(known)!=connection['known_hosts_sha256']: raise ValueError('SSH trust file changed; review connection')
        self.command=['ssh','-F',os.devnull,'-T','-b',connection['source'],
                      '-o','ConnectTimeout=8','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3',
                      '-o','StrictHostKeyChecking=yes','-o','HostKeyAlgorithms=+ssh-rsa',
                      '-o','UserKnownHostsFile="'+str(known)+'"','root@'+connection['host']]
    def __call__(self, command, **kwargs):
        # Lock spans one remote command; a stale lock is never removed automatically.
        wrapped="umask 077; mkdir /tmp/schoolbell-release.lock || exit 1; trap 'rmdir /tmp/schoolbell-release.lock' EXIT; sh -c "+shlex.quote(command)
        result=subprocess.run(self.command+[wrapped],check=True,timeout=240,**kwargs)
        if isinstance(result.stdout,bytes) and len(result.stdout)>32*1024*1024: raise ValueError('Remote response too large')
        return result

def connection(host,source,known):
    for value in (host,source): ipaddress.IPv4Address(value)
    known=Path(known).resolve()
    return dict(host=host,source=source,known_hosts=str(known),known_hosts_sha256=plan.sha(known))

def cache_bundle(session,root,doc,rows,recovery):
    legacy=session/'payload'; (legacy/'bundle').mkdir(parents=True)
    (legacy/'firmware').mkdir()
    translated=[]
    for row in rows:
        row=dict(row); original=row['file']; row['file']=Path(original).name
        row['file_blocks_estimate']=max(1,row.pop('payload_blocks_bytes'))
        shutil.copyfile(root/original,legacy/'bundle'/row['file']);translated.append(row)
    legacy_doc=dict(doc,packages=translated)
    write_json(legacy/'bundle/manifest.json',legacy_doc)
    shutil.copyfile(recovery,legacy/'firmware/tp_recovery.bin')
    if plan.sha(legacy/'firmware/tp_recovery.bin')!=RECOVERY_SHA: raise ValueError('Wrong recovery image')
    target=next(row for row in translated if row['name']=='modbus-schoolbell')
    return legacy,{'package':target}

def prepare(session,archive,recovery,conn,remote,emit=print):
    with guard(session,create=True) as state:
        # Validate all local material before the first connection.
        raw=zip_bytes(archive); (state/'bundle.zip').write_bytes(raw)
        root,doc,rows,digest=unpack(raw,state/'archive')
        if plan.sha(recovery)!=RECOVERY_SHA: raise ValueError('Wrong recovery image; no device access')
        legacy,manifest=cache_bundle(state,root,doc,rows,recovery)
        snapshot=remote((root/'scripts/snapshot.sh').read_text(encoding='utf8'),stdout=subprocess.PIPE).stdout.decode('utf8')
        report=plan.plan(root,snapshot)
        if report['mode']!='fresh': raise ValueError('Already current; no fresh installation is needed')
        (state/'snapshot.tsv').write_text(snapshot,encoding='utf8')
        write_json(state/'plan.json',report)
        args=SimpleNamespace(session=str(state),source=conn['source'],index=0)
        fresh.prepare(args,legacy,manifest,remote,BASE,emit)
        backed_up=json.loads((state/'prepared.json').read_bytes())
        if backed_up['inventory']!=plan.snapshot(snapshot)[1]:
            raise ValueError('Inventory changed during preparation; use a new session')
        # Bind receipt, immutable ZIP, connection and recovery after successful backup.
        write_json(state/'session.json',dict(format=1,connection=conn,version=doc['version'],
                   zip_sha256=plan.sha(state/'bundle.zip'),prepared_sha256=plan.sha(state/'prepared.json'),
                   payload_manifest_sha256=plan.sha(legacy/'bundle/manifest.json')))
        emit('PREPARED. Backup verified; install is a separate confirmed command.')

def receipt(state):
    for path in state.rglob('*'):
        if path.is_symlink(): raise ValueError('Symlink session content')
    doc=json.loads((state/'session.json').read_bytes())
    if doc['format']!=1: raise ValueError('Unknown session format')
    for path,key in [('bundle.zip','zip_sha256'),('prepared.json','prepared_sha256'),('payload/bundle/manifest.json','payload_manifest_sha256')]:
        if plan.sha(state/path)!=doc[key]: raise ValueError('Session evidence changed: '+path)
    data=json.loads((state/'prepared.json').read_bytes())
    fresh.evidence(state,data)
    fresh.load_bundle(state/'payload',data['manifest']['package'])
    return doc,data

def resume(session,action,remote_factory=SSH,confirm=None,emit=print):
    with guard(session) as state:
        if action=='verify': (state/'verified.json').unlink(missing_ok=True)
        doc,data=receipt(state)
        if action=='install':
            if (state/'write-started').exists(): raise ValueError('Write may have started; use verify, never retry install')
            expected='INSTALL '+doc['connection']['host']
            if confirm!=expected: raise ValueError('Explicit confirmation required: '+expected)
        elif not (state/'write-started').is_file(): raise ValueError('No installation attempt to verify')
        remote=remote_factory(doc['connection'])
        args=SimpleNamespace(session=str(state),source=doc['connection']['source'],index=0,action=action)
        fresh.resume(args,state/'payload',data,remote,BASE,OFF,emit)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='action',required=True)
    prep=sub.add_parser('prepare'); prep.add_argument('--zip',type=Path,required=True)
    prep.add_argument('--recovery',type=Path,required=True)
    prep.add_argument('--host',required=True);prep.add_argument('--source',required=True)
    prep.add_argument('--known-hosts',type=Path,required=True);prep.add_argument('--session',type=Path,required=True)
    for action in ('install','verify'):
        command=sub.add_parser(action);command.add_argument('--session',type=Path,required=True)
    args=parser.parse_args()
    try:
        if args.action=='prepare':
            conn=connection(args.host,args.source,args.known_hosts)
            prepare(args.session,args.zip,args.recovery,conn,SSH(conn))
        else:
            answer=None
            if args.action=='install':
                print('Keep power and Ethernet connected. Automatic bells must remain off.')
                answer=input('Type INSTALL followed by the router IPv4 address: ')
            resume(args.session,args.action,confirm=answer)
    except (ValueError,KeyError,OSError,subprocess.SubprocessError,zipfile.BadZipFile) as error:
        parser.exit(1,'STOPPED: '+str(error)+'\nKeep the session and backups. If write-started exists, verify; do not repeat installation.\n')
