"""GUI adapter for the shared ZIP transaction. Inspection never connects to a device."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
RUNTIME=HERE/'zip-runtime'
if not RUNTIME.is_dir():
    RUNTIME=HERE.parents[2]/'packaging/release'
    sys.path.insert(0,str(HERE.parents[2]/'scripts'))
sys.path.insert(0,str(RUNTIME))
import install as transaction
import package_worker as legacy

TARGET='192.168.1.1'

def version(value):
    if not isinstance(value,str) or not re.fullmatch(r'[0-9]+[.][0-9]+[.][0-9]+',value):
        raise ValueError('Invalid wizard compatibility version')
    return tuple(map(int,value.split('.')))

def inspect(archive,wizard_version):
    raw=transaction.zip_bytes(archive)
    with tempfile.TemporaryDirectory(prefix='schoolbell-zip-check-') as temp:
        root,doc,rows,digest=transaction.unpack(raw,Path(temp)/'archive')
        wizard=doc['wizard']
        if wizard['bundle_format']!=1 or version(wizard['minimum_version'])>version(wizard_version):
            raise ValueError('This ZIP requires a newer wizard')
        if not (root/'scripts/snapshot.sh').is_file(): raise ValueError('ZIP has no device snapshot script')
    return dict(path=str(Path(archive).resolve()),sha256=hashlib.sha256(raw).hexdigest(),
                version=doc['version'],status=doc['status'])

def archive_allowed(folder):
    state=folder/'zip-session'
    if not (state/'write-started').exists(): return
    doc,data=transaction.receipt(state)
    proof=json.loads((state/('verified.json' if (state/'verified.json').exists() else 'unchanged.json')).read_bytes())
    if (proof.get('prepared_sha256')!=transaction.plan.sha(state/'prepared.json') or
        proof.get('marker_sha256')!=transaction.plan.sha(state/'write-started') or
        proof.get('version')!=doc['version']):
        raise ValueError('Verify the ZIP installation before archiving this session')

def run_core(args,root=None,route_check=None,transport=None,emit=print):
    root=Path(root or HERE);state=Path(args.session)
    route_check=route_check or legacy.route
    transport=transport or transaction.SSH
    if args.action=='inspect-zip':
        if (state/'prepared.json').exists() or (state/'zip-session').exists() or (state/'zip-binding.json').exists():
            raise ValueError('Start a new session before choosing another bundle')
        selected=inspect(args.zip,(root/'wizard-version.txt').read_text().strip())
        temp=state/'zip-selection.tmp'
        temp.write_text(json.dumps(selected),encoding='utf8');temp.replace(state/'zip-selection.json')
        emit('ZIP VERIFIED. Школьник '+selected['version']+' · новая установка · '+selected['status'])
        return
    if args.action=='verify':
        for name in ('verified.json','unchanged.json'):(state/'zip-session'/name).unlink(missing_ok=True)
    if (state/'prepared.json').exists(): raise ValueError('Legacy session cannot become a ZIP session')
    if args.action=='prepare':
        if (state/'zip-session').exists() or (state/'zip-binding.json').exists():
            raise ValueError('Preparation already exists; install or start a new session')
        selected=json.loads((state/'zip-selection.json').read_bytes())
        if str(Path(args.zip).resolve())!=selected['path']: raise ValueError('Selected ZIP changed')
        raw=transaction.zip_bytes(selected['path'])
        if hashlib.sha256(raw).hexdigest()!=selected['sha256']: raise ValueError('ZIP changed after inspection; select it again')
        # Pin the bytes before preparation: source-file replacement cannot change the operation.
        (state/'selected.zip').write_bytes(raw)
        known=Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup/known_hosts'
        conn=transaction.connection(TARGET,args.source,known)
        transaction.write_json(state/'zip-binding.json',dict(source=args.source,index=args.index,selection=selected))
        remote=transport(conn)
        def checked(command,**kw):
            route_check(args.source,args.index)
            return remote(command,**kw)
        transaction.prepare(state/'zip-session',state/'selected.zip',root/'firmware/tp_recovery.bin',conn,checked,emit)
        return
    if args.action not in ('install','verify'): raise ValueError('Unsupported ZIP operation')
    binding=json.loads((state/'zip-binding.json').read_bytes())
    if (args.source,args.index)!=(binding['source'],binding['index']): raise ValueError('Prepared connection changed')
    def factory(conn):
        remote=transport(conn)
        def checked(command,**kw):
            route_check(args.source,args.index)
            return remote(command,**kw)
        return checked
    try:
        transaction.resume(state/'zip-session',args.action,factory,
                           'INSTALL '+TARGET if args.action=='install' else None,emit)
    except Exception:
        if args.action=='verify':
            try:
                doc,data=transaction.receipt(state/'zip-session')
                transaction.fresh.unchanged(data,factory(doc['connection']),transaction.BASE)
                transaction.write_json(state/'zip-session/unchanged.json',dict(
                    version=doc['version'],prepared_sha256=transaction.plan.sha(state/'zip-session/prepared.json'),
                    marker_sha256=transaction.plan.sha(state/'zip-session/write-started')))
                emit('UNCHANGED VERIFIED. Установка не выполнена; исходный состав пакетов и настройки сохранены. Начните новый сеанс.')
                return
            except Exception:
                pass
            try:
                conn=transaction.connection(TARGET,args.source,Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup/known_hosts')
                result=factory(conn)("""echo ZIP_DIAGNOSTICS
cat /tmp/sysinfo/board_name
opkg status modbus-schoolbell | sed -n '/^Package:/p;/^Version:/p;/^Status:/p'
for f in /etc/schoolbell-editor/package.pending /tmp/schoolbell-sound-test.lock/package-owner; do
 if test -f "$f"; then echo "$f:"; cat "$f"; fi
done
for svc in schoolbell-auto uhttpd; do /etc/init.d/$svc running; echo "$svc running=$?"; done
df -k /overlay /tmp
free
dmesg | tail -60 | sed -n '/Out of memory/p;/Killed process/p;/oom-killer/p'
echo ZIP_DIAGNOSTICS_END
""",stdout=-1)
                emit(result.stdout.decode('utf8',errors='replace'))
            except Exception as diagnostic_error:
                emit('Read-only diagnostics unavailable: '+str(diagnostic_error))
        raise
