"""Windows GUI package-upgrade worker. No firmware/network configuration operations."""
import argparse, hashlib, json, os, re, subprocess, sys, tarfile, time, uuid
from pathlib import Path
from session_lock import lease, marker, recover
from operation_protocol import Operation, Cancelled, checkpoint, phase

CHECK = """set -eu
. /etc/openwrt_release
test "$(id -u)" = 0
test "$(cat /tmp/sysinfo/board_name)" = 'tplink,tl-mr3020-v3'
test "$DISTRIB_RELEASE:$DISTRIB_TARGET:$DISTRIB_ARCH" = '19.07.9:ramips/mt76x8:mipsel_24kc'
test "$(opkg status kernel | sed -n 's/^Version: //p')" = '4.14.267-1-d92769dc5268e102503ae83fe968a56c'
test "$(opkg status modbus-schoolbell-clock | sed -n 's/^Version: //p')" = '1.0.0'
test ! -e /etc/schoolbell-editor/package.pending
"""
BASE_CHECK = CHECK.replace("test \"$(opkg status modbus-schoolbell-clock | sed -n 's/^Version: //p')\" = '1.0.0'\n", "") + "test \"$(opkg status libc | sed -n 's/^Version: //p')\" = '1.1.24-2'\n"
SNAPSHOT = """lua - <<'LUA'
package.path='/usr/share/schoolbell-editor/lua/?.lua;'..package.path
local a=require('schoolbell.automatic_store');local active=a.decode(a.raw());assert(not active.enabled,'Automatic bells must be off')
local c=require('schoolbell.controls').read()
print(c.volume_db);print(tostring(c.muted));print(tostring(c.confirm_play==true))
local codec=require('schoolbell.media_codec');print(active.revision or 'no-active-plan')
local f=io.open('/etc/schoolbell-editor/current.json','rb');local draft=f and f:read('*a') or '';if f then f:close() end
print(codec.sha(draft))
LUA
"""

def digest(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for chunk in iter(lambda:f.read(65536),b''): h.update(chunk)
    return h.hexdigest()

def emit(message):
    print(message, flush=True)

def route(source,index):
    import ipaddress
    ipaddress.IPv4Address(source)
    if index < 1: raise ValueError('Select a dedicated Ethernet adapter')
    code = "$r=@(Find-NetRoute -RemoteIPAddress 192.168.1.1 -LocalIPAddress '%s' | Where-Object DestinationPrefix); if ($r.Count -ne 1 -or $r[0].InterfaceIndex -ne %d -or $r[0].NextHop -ne '0.0.0.0') {exit 1}" % (source,index)
    subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',code],check=True,timeout=30,stdout=subprocess.DEVNULL)

def validate(root):
    manifest=json.loads((root/'payload.json').read_text(encoding='utf-8-sig'))
    for name in ('package','rollback'):
        row=manifest[name]
        if not re.fullmatch(r'modbus-schoolbell_[0-9]+\.[0-9]+\.[0-9]+_all\.ipk',row['file']): raise ValueError('Invalid package name')
        if digest(root/row['file'])!=row['sha256']: raise ValueError('Package checksum mismatch')
    return manifest

def run_core(args):
    import io, shlex, shutil
    root=Path(__file__).resolve().parent
    if args.action!='backup' and (args.action=='inspect-zip' or getattr(args,'zip','') or (Path(args.session)/'zip-binding.json').exists() or (Path(args.session)/'zip-session').exists()):
        import zip_worker
        return zip_worker.run_core(args,root)
    if args.action in ("verify","install"):
        (Path(args.session)/"verified.json").unlink(missing_ok=True)
    state=Path(args.session);state.mkdir(parents=True,exist_ok=True)
    receipt=state/'prepared.json'
    if args.action=='verify':
        # Verify the saved operation, even after the application bundle was rebuilt.
        manifest=json.loads(receipt.read_text())['manifest']
        for row in manifest.values():
            if not re.fullmatch(r'modbus-schoolbell_[0-9]+\.[0-9]+\.[0-9]+_all\.ipk',row['file']):
                raise ValueError('Invalid saved package name')
    elif args.action!='backup':
        manifest=validate(root)
    ssh=['ssh.exe','-F','NUL','-b',args.source,'-o','ConnectTimeout=8','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3','-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=yes','-o','NumberOfPasswordPrompts=1','-o','UserKnownHostsFile="'+str(Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup/known_hosts')+'"','root@192.168.1.1']
    def remote(command, **kw):
        checkpoint(args)
        route(args.source,args.index)
        result=subprocess.run(ssh+[command],check=True,timeout=240,**kw)
        checkpoint(args)
        return result
    if args.action=='backup':
        if (state/'write-started').exists() or (state/'zip-session/write-started').exists(): raise ValueError('Verify and archive the earlier write first')
        import device_backup
        snapshot="if test -f /usr/share/schoolbell-editor/lua/schoolbell/automatic_store.lua; then\n"+SNAPSHOT+"else echo no-schoolbell; fi\n"
        phase(args,"backup")
        device_backup.backup(args,remote,BASE_CHECK,snapshot,emit)
        return "backedup"
    if args.action in ('install','verify'):
        saved=json.loads(receipt.read_text())
        if saved.get('mode')=='fresh':
            import fresh_install
            phase(args,"verifying")
            fresh_install.resume(args,root,saved,remote,BASE_CHECK,SNAPSHOT,emit)
            return "done"
    identity_command="cat /sys/class/net/br-lan/address; cat /proc/sys/kernel/random/boot_id; opkg status modbus-schoolbell | sed -n 's/^Version: //p'"
    space='test "$(df -k /overlay | awk \'END {print $4}\')" -ge 1024; test "$(df -k /tmp | awk \'END {print $4}\')" -ge 6144\n'
    if args.action=='prepare':
        if (state/'write-started').exists(): raise ValueError('Previous write requires verification; preparation cannot replace its evidence')
        if receipt.exists(): receipt.unlink()
        version=remote(BASE_CHECK+"opkg status modbus-schoolbell | sed -n 's/^Version: //p'\n# GUI_VERSION_PROBE\n",stdout=subprocess.PIPE).stdout.decode().strip()
        if version==manifest['package']['version']:
            result=remote(CHECK+"test \"$(opkg status modbus-schoolbell | sed -n 's/^Version: //p')\" = "+shlex.quote(version)+'\n'+SNAPSHOT+'/etc/init.d/schoolbell-auto running\n/etc/init.d/uhttpd running\necho GUI_CURRENT_VERIFIED\n',stdout=subprocess.PIPE)
            if not result.stdout.rstrip().endswith(b'GUI_CURRENT_VERIFIED'):
                raise ValueError('Current installation proof missing')
            emit('ALREADY CURRENT. Школьник '+version+' уже установлен. Службы работают, автозвонки выключены. Запись не выполнялась.')
            return 'current'
        if not version:
            import fresh_install
            return fresh_install.prepare(args,root,manifest,remote,BASE_CHECK,emit)
        if version!=manifest['rollback']['version']:
            raise ValueError('Нет подходящего сценария для версии '+(version or 'без установленного Школьника')+'. Установка не запускалась.')
        emit('Checking device and saving overlay backup in one SSH session...')
        command=CHECK+space+"""umask 077
d=$(mktemp -d /tmp/schoolbell-gui.XXXXXX)
trap 'rm -rf "$d"' EXIT
"""+'test "$(opkg status modbus-schoolbell | sed -n \'s/^Version: //p\')" = '+shlex.quote(manifest['rollback']['version'])+'\n'+"{ "+identity_command+"; } > \"$d/identity.txt\"\n"+"{ "+SNAPSHOT+"} > \"$d/sound.txt\"\n"+"""tar -C /overlay -cf "$d/overlay.tar" .
"""+"{ "+SNAPSHOT+"} > \"$d/sound-after.txt\"\n"+"""cmp "$d/sound.txt" "$d/sound-after.txt"
tar -C "$d" -cf "$d/backup.tar" overlay.tar identity.txt sound.txt
sha256sum "$d/backup.tar"
cat "$d/backup.tar"
"""
        raw=remote(command,stdout=subprocess.PIPE).stdout
        header,separator,archive=raw.partition(b'\n')
        checksum=header.split()[0].decode() if separator else ''
        if not re.fullmatch('[0-9a-f]{64}',checksum) or hashlib.sha256(archive).hexdigest()!=checksum: raise ValueError('Backup transfer checksum mismatch')
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            if sorted(tar.getnames())!=['identity.txt','overlay.tar','sound.txt']: raise ValueError('Unexpected backup contents')
            identity=tar.extractfile('identity.txt').read().decode().strip()
            sound=tar.extractfile('sound.txt').read().decode().strip()
            overlay=tar.extractfile('overlay.tar').read()
        lines=identity.splitlines()
        if len(lines)!=3 or lines[2]!=manifest['rollback']['version']: raise ValueError('No matching rollback version')
        with tarfile.open(fileobj=io.BytesIO(overlay)) as tar:
            members=tar.getmembers()
            if not any(m.isdir() and m.name.rstrip('/').endswith('/etc/schoolbell-editor') for m in members): raise ValueError('Settings directory missing from backup')
            for member in members:
                if member.isfile():
                    f=tar.extractfile(member)
                    while f.read(65536): pass
        (state/'backup.tar').write_bytes(archive)
        (state/'overlay.tar').write_bytes(overlay)
        shutil.copy2(root/manifest['rollback']['file'],state/manifest['rollback']['file'])
        data={'identity':identity,'sound':sound,'backup_sha256':checksum,'overlay_sha256':digest(state/'overlay.tar'),'source':args.source,'index':args.index,'created':time.time(),'manifest':manifest}
        receipt.write_text(json.dumps(data))
        emit('BACKUP VERIFIED. Ready to update '+lines[2]+' -> '+manifest['package']['version'])
    else:
        data=json.loads(receipt.read_text())
        if data['source']!=args.source or data['index']!=args.index or data['manifest']!=manifest: raise ValueError('Preparation differs; prepare again')
        if digest(state/'backup.tar')!=data['backup_sha256'] or digest(state/'overlay.tar')!=data['overlay_sha256']: raise ValueError('Backup checksum mismatch')
        if digest(state/manifest['rollback']['file'])!=manifest['rollback']['sha256']: raise ValueError('Rollback checksum mismatch')
        expected=data['identity'].splitlines()
        binding='test "$(cat /sys/class/net/br-lan/address)" = '+shlex.quote(expected[0])+'; test "$(cat /proc/sys/kernel/random/boot_id)" = '+shlex.quote(expected[1])+'\n'
        sound_check='{ '+SNAPSHOT+'} > "$d/sound.txt"\nprintf \'%s\\n\' '+shlex.quote(data['sound'])+' > "$d/expected.txt"\ncmp "$d/sound.txt" "$d/expected.txt"\n'
        command=CHECK+binding+"""umask 077
d=$(mktemp -d /tmp/schoolbell-gui.XXXXXX)
trap 'rm -rf "$d"' EXIT
"""+sound_check
        if args.action=='install':
            if time.time()-data['created']>1800: raise ValueError('Preparation expired; prepare again')
            marker=state/'write-started'
            if marker.exists(): raise ValueError('Previous write outcome unknown. Verify first; do not repeat installation')
            # Marker precedes the connection: unknown authentication/transfer outcomes fail closed.
            marker.write_text('Installation may have started. Verify device before any retry. Attempt: '+uuid.uuid4().hex)
            row=manifest['package']
            emit('Installing and verifying in one SSH session. Keep power and cable connected.')
            command+=space+'test "$(opkg status modbus-schoolbell | sed -n \'s/^Version: //p\')" = '+shlex.quote(expected[2])+'\n'+"""cat > "$d/package.ipk"
echo '%s  '"$d/package.ipk" | sha256sum -c -
opkg install "$d/package.ipk"
""" % row['sha256']
        command+=CHECK+'test "$(opkg status modbus-schoolbell | sed -n \'s/^Version: //p\')" = '+shlex.quote(manifest['package']['version'])+'\n'+sound_check+'/etc/init.d/schoolbell-auto running\n/etc/init.d/uhttpd running\necho GUI_RESULT_VERIFIED\n'
        if args.action=='install':
            with (root/manifest['package']['file']).open('rb') as f: result=remote(command,stdin=f,stdout=subprocess.PIPE)
        else: result=remote(command,stdout=subprocess.PIPE)
        if not result.stdout.rstrip().endswith(b'GUI_RESULT_VERIFIED'): raise ValueError('Result proof missing')
        (state/'verified.json').write_text(json.dumps({'version':manifest['package']['version'],'time':time.time(),'prepared_sha256':digest(receipt),'marker_sha256':digest(state/'write-started') if (state/'write-started').exists() else None}))
        emit('UPGRADE VERIFIED. Automatic bells off; volume and plan unchanged.')
        return 'done'

def archive_allowed(folder):
    """Local evidence check only: never converts an uncertain write to success."""
    if (folder/'zip-session').exists():
        import zip_worker
        zip_worker.archive_allowed(folder)
    marker=folder/'write-started'
    if not marker.exists(): return
    data=json.loads((folder/'prepared.json').read_text())
    proof=json.loads((folder/'verified.json').read_text())
    if proof.get('prepared_sha256')!=digest(folder/'prepared.json') or proof.get('marker_sha256')!=digest(marker):
        raise ValueError('Сначала проверьте результат установки: подтверждение отсутствует или устарело')
    if proof.get('version')!=data['manifest']['package']['version']:
        raise ValueError('Verified version differs from preparation')
    if data.get('mode')=='fresh':
        import fresh_install
        fresh_install.evidence(folder,data)
        return
    for filename,expected in [('backup.tar',data['backup_sha256']),('overlay.tar',data['overlay_sha256']),
                              (data['manifest']['rollback']['file'],data['manifest']['rollback']['sha256'])]:
        if Path(filename).name!=filename or digest(folder/filename)!=expected:
            raise ValueError('Сохранённая копия повреждена; новый сеанс заблокирован')


def run(args):
    folder=Path(args.session)
    with lease(folder):
        if args.action=="recover-session":
            result=recover(folder)
            emit("Локальный сеанс восстановлен. Установка не повторялась; проверьте результат или начните новый сеанс.")
            return result
        return run_locked(args)

def run_locked(args):
    import uuid
    folder=Path(args.session);folder.parent.mkdir(parents=True,exist_ok=True)
    # Stable lock spans archival and recreation of the active session directory.
    guard=folder.parent/(folder.name+'.guard')
    marker(guard)
    lock=None
    try:
        folder.mkdir(parents=True,exist_ok=True)
        candidate=folder/'operation.lock'
        marker(candidate)
        lock=candidate
        if args.action=='new-session':
            phase(args,'archiving')
            archive_allowed(folder)
            archive=folder.parent/'session-history'
            archive.mkdir(exist_ok=True)
            destination=archive/(time.strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:12])
            folder.rename(destination)
            lock=destination/'operation.lock'
            folder.mkdir()
            emit('Предыдущий сеанс сохранён: '+str(destination))
            emit('Новый сеанс готов. Выберите подключение и сохраните новую копию.')
            return 'idle'
        else:
            checkpoint(args)
            return run_core(args)
    finally:
        if lock is not None: lock.unlink()
        guard.unlink()

def dispatch(args):
    folder=Path(args.session)
    if args.action in ('prepare','install') and not (getattr(args,'zip','') or (folder/'zip-binding.json').exists()):
        raise ValueError('Select an external ZIP; embedded package installation is no longer supported')
    return run(args)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('action',choices=['prepare','install','verify','new-session','backup','inspect-zip','recover-session']);p.add_argument('--source',required=True);p.add_argument('--index',required=True,type=int);p.add_argument('--session',required=True);p.add_argument('--zip',default='')
    p.add_argument('--operation-id',default='');p.add_argument('--session-id',default='')
    try:
        args=p.parse_args()
        if args.operation_id or args.session_id:
            Operation(args).execute(args,dispatch)
        else:
            dispatch(args)
    except Cancelled as exc:
        emit(str(exc));sys.exit(2)
    except subprocess.CalledProcessError as exc:
        if isinstance(exc.stdout,bytes): emit(exc.stdout[-32768:].decode("utf8",errors="replace"))
        emit('Остановлено: SSH или проверка устройства завершились с кодом '+str(exc.returncode)+'. Подробности выше. Пакет не повторяется автоматически.');sys.exit(1)
    except subprocess.TimeoutExpired:
        emit('Остановлено: истекло время ожидания. Если запись началась, сначала проверьте результат.');sys.exit(1)
    except Exception as exc:
        emit('STOP: '+str(exc));sys.exit(1)
