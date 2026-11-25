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
from session_lock import marker
from operation_protocol import Cancelled, checkpoint, phase

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
        phase(args,'validating-zip')
        checkpoint(args)
        selected=inspect(args.zip,(root/'wizard-version.txt').read_text().strip())
        checkpoint(args)
        temp=state/'zip-selection.tmp'
        temp.write_text(json.dumps(selected),encoding='utf8');temp.replace(state/'zip-selection.json')
        emit('ZIP VERIFIED. Школьник '+selected['version']+' · новая установка · '+selected['status'])
        return 'idle'
    if args.action=='verify':
        for name in ('verified.json','unchanged.json'):(state/'zip-session'/name).unlink(missing_ok=True)
    if (state/'prepared.json').exists(): raise ValueError('Legacy session cannot become a ZIP session')
    if args.action=='prepare':
        if (state/'zip-session').exists() or (state/'zip-binding.json').exists():
            raise ValueError('Preparation already exists; install or start a new session')
        phase(args,'preparing')
        checkpoint(args)
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
            checkpoint(args)
            route_check(args.source,args.index)
            result=remote(command,**kw)
            checkpoint(args)
            return result
        transaction.prepare(state/'zip-session',state/'selected.zip',root/'firmware/tp_recovery.bin',conn,checked,emit,marker_writer=marker)
        return 'ready'
    if args.action not in ('install','verify'): raise ValueError('Unsupported ZIP operation')
    binding=json.loads((state/'zip-binding.json').read_bytes())
    if (args.source,args.index)!=(binding['source'],binding['index']): raise ValueError('Prepared connection changed')
    def factory(conn):
        remote=transport(conn)
        def checked(command,**kw):
            checkpoint(args)
            route_check(args.source,args.index)
            result=remote(command,**kw)
            checkpoint(args)
            return result
        return checked
    phase(args,'installing' if args.action=='install' else 'verifying')
    checkpoint(args)
    try:
        transaction.resume(state/'zip-session',args.action,factory,
                           'INSTALL '+TARGET if args.action=='install' else None,emit,marker_writer=marker)
        return 'done'
    except Cancelled:
        raise
    except Exception:
        if args.action=='verify':
            try:
                doc,data=transaction.receipt(state/'zip-session')
                transaction.fresh.unchanged(data,factory(doc['connection']),transaction.BASE)
                transaction.write_json(state/'zip-session/unchanged.json',dict(
                    version=doc['version'],prepared_sha256=transaction.plan.sha(state/'zip-session/prepared.json'),
                    marker_sha256=transaction.plan.sha(state/'zip-session/write-started')))
                emit('UNCHANGED VERIFIED. Установка не выполнена; исходный состав пакетов и настройки сохранены. Начните новый сеанс.')
                return 'not-applied'
            except Cancelled:
                raise
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


# GUI policy (spec 1.23): every explicit install is a new attempt, including
# same-version repair and retry. The conservative standalone ZIP CLI is unchanged.
def ensure_host(args, state, emit=print):
    import base64
    import subprocess
    known=Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup/known_hosts'
    known.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run(['ssh-keyscan','-T','8','-t','rsa',TARGET],
                          capture_output=True,check=True,timeout=15)
    lines=[line for line in result.stdout.decode('ascii').splitlines()
           if line.startswith(TARGET+' ssh-rsa ')]
    if len(lines)!=1: raise ValueError('Не удалось прочитать SSH-ключ роутера. Повторите подключение.')
    line=lines[0]
    fingerprint='SHA256:'+base64.b64encode(hashlib.sha256(base64.b64decode(line.split()[2],validate=True)).digest()).decode().rstrip('=')
    existing=known.read_text() if known.exists() else ''
    if line not in existing.splitlines():
        pending=state/'pending-host.json'
        pending.write_text(json.dumps(dict(fingerprint=fingerprint,source=args.source,index=args.index)),encoding='utf8')
        if getattr(args,'trusted_host_key','')!=fingerprint:
            raise ValueError('Новый SSH-ключ: '+fingerprint+'. Подтвердите ключ в форме и повторите действие.')
        # Replace only this target, retaining all other trust entries.
        retained=[x for x in existing.splitlines() if not x.startswith(TARGET+' ')]
        temporary=known.with_suffix('.tmp')
        temporary.write_text('\n'.join(retained+[line])+'\n',encoding='ascii');temporary.replace(known)
        emit('SSH-ключ принят пользователем: '+fingerprint)
    (state/'pending-host.json').unlink(missing_ok=True)
    return transaction.connection(TARGET,args.source,known)


def install_rows(rows, installed):
    # Retain firmware-provided dependencies; repair both project packages.
    return [r for r in rows if r['name'] in ('modbus-schoolbell','modbus-schoolbell-clock') or r['name'] not in installed]


def run_retry(args, root=None, route_check=None, transport=None, trust=None, emit=print):
    import io
    import shlex
    import subprocess
    import tarfile
    import uuid
    state=Path(args.session);root=Path(root or HERE)
    route_check=route_check or legacy.route
    inspect(args.zip,(root/'wizard-version.txt').read_text().strip())
    route_check(args.source,args.index)
    conn=(trust or ensure_host)(args,state,emit)
    if transport:
        remote=transport(conn)
    else:
        ssh=transaction.SSH(conn)
        def remote(command, **kw):
            checkpoint(args)
            route_check(args.source,args.index)
            if len(command.encode('utf8'))>8000: raise ValueError('Команда превышает ограничение Dropbear')
            return legacy.ssh_run(ssh.command+[command],**kw)
    base='set -eu\ntest -f /etc/openwrt_release\ntest "$(id -u)" = 0\ncommand -v opkg >/dev/null\n'
    if args.action=='verify':
        target_version=inspect(args.zip,(root/'wizard-version.txt').read_text().strip())['version']
        remote(verify_command(base,target_version),stdout=subprocess.PIPE)
        emit('INSTALL VERIFIED. Школьник '+target_version+' установлен; службы работают, автозвонки выключены.')
        return 'done'
    if args.action=='prepare':
        phase(args,'preparing')
        result=remote(base+'cat /etc/openwrt_release; opkg status modbus-schoolbell; df -k /overlay /tmp\n',stdout=subprocess.PIPE)
        emit(result.stdout.decode('utf8',errors='replace'))
        emit('OpenWrt доступна. Проверка необязательна; можно установить комплект, в том числе поверх существующего.')
        return 'ready'
    if args.action!='install': raise ValueError('Unsupported repeatable action')
    # A fresh immutable attempt directory preserves every old log, backup and marker.
    attempt=state/'attempts'/uuid.uuid4().hex;attempt.mkdir(parents=True)
    raw=transaction.zip_bytes(args.zip);(attempt/'bundle.zip').write_bytes(raw)
    payload,doc,rows,digest=transaction.unpack(raw,attempt/'archive')
    phase(args,'installing')
    info=remote(base+'cat /etc/openwrt_release; df -k /overlay /tmp\n',stdout=subprocess.PIPE).stdout.decode('utf8',errors='replace')
    emit(info)
    if '19.07.9' not in info: emit('ПРЕДУПРЕЖДЕНИЕ: комплект рассчитан на OpenWrt 19.07.9; совместимость определит opkg.')
    installed=transaction.fresh.inventory(remote(base+'opkg list-installed\n',stdout=subprocess.PIPE).stdout.decode())
    old=installed.get('modbus-schoolbell')
    emit('Установка поверх '+old+' → '+doc['version'] if old else 'Новая установка '+doc['version'])
    if old and re.fullmatch(r'[0-9]+[.][0-9]+[.][0-9]+',old) and version(old)>version(doc['version']): emit('ПРЕДУПРЕЖДЕНИЕ: устанавливается более ранняя версия; совместимость настроек не гарантирована.')
    emit('Резервная копия необязательна. Настройки сохраняются; ошибки opkg будут показаны без запрета следующей попытки.')
    selected=install_rows(rows,installed)
    archive=io.BytesIO()
    with tarfile.open(fileobj=archive,mode='w') as tar:
        for row in selected: tar.add(payload/row['file'],arcname=Path(row['file']).name,recursive=False)
        checks=''.join(r['sha256']+'  '+Path(r['file']).name+'\n' for r in selected).encode()
        info=tarfile.TarInfo('SHA256SUMS');info.size=len(checks);tar.addfile(info,io.BytesIO(checks))
    command=base+transaction.fresh.TEMP+'''{
'''+transaction.fresh.PROTECTED+'''for f in /etc/schoolbell-editor/current.json /etc/schoolbell-editor/sound-control.json; do
 if test -f "$f"; then sha256sum "$f"; fi
done
} > "$d/preserved.sha256"
'''+ 'cd "$d"\ntar xf -\nsha256sum -c SHA256SUMS\n'
    command+='opkg --force-reinstall --force-downgrade install '+' '.join(shlex.quote('./'+Path(r['file']).name) for r in selected)+'\n'
    command+="grep -v '^missing ' \"$d/preserved.sha256\" > \"$d/existing.sha256\"\nsha256sum -c \"$d/existing.sha256\"\n"
    command+=verify_command('',doc['version'])
    (attempt/'write-started').write_text('Explicit installation attempt; failure permits a new attempt.\n')
    result=remote(command,input=archive.getvalue(),stdout=subprocess.PIPE)
    emit(result.stdout.decode('utf8',errors='replace'))
    transaction.write_json(attempt/'verified.json',dict(version=doc['version'],bundle_sha256=hashlib.sha256(raw).hexdigest()))
    emit('INSTALL VERIFIED. Школьник '+doc['version']+' установлен; службы работают, автозвонки выключены.')
    return 'done'


def verify_command(base, version):
    import shlex
    return (base+'test "$(opkg status modbus-schoolbell | sed -n '+shlex.quote('s/^Version: //p')+')" = '+shlex.quote(version)+'\n'
            +transaction.OFF+'/etc/init.d/schoolbell-auto running\n/etc/init.d/uhttpd running\necho INSTALL_VERIFIED\n')
