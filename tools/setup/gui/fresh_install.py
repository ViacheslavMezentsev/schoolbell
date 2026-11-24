"""Fresh-install transaction; all device access is injected by package_worker."""
import hashlib
import io
import json
from pathlib import Path
import re
import shlex
import shutil
import tarfile
import time
import uuid

RECOVERY_SHA = 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'
MAX_BACKUP_BYTES = 32 * 1024 * 1024

# Same accepted stock LuCI alternatives as the existing console installer.
STOCK = {name: 'git-22.045.73925-36e5c1c-1' for name in
         ('luci-base','luci-lib-ip','luci-lib-jsonc','luci-lib-nixio','luci-theme-bootstrap')}
STOCK.update({'libubus-lua':'2021-07-01-38c7fdd8-1','libubus20210603':'2021-07-01-38c7fdd8-1'})
FRESH = """test -z "$(opkg status modbus-schoolbell | sed -n 's/^Version: //p')"
test ! -e /etc/schoolbell-editor
test ! -e /etc/modbus-schoolbell
"""
PROTECTED = """for f in /etc/config/network /etc/config/wireless /etc/config/system /etc/config/dhcp /etc/config/firewall /etc/config/dropbear /etc/shadow; do
 if test -f "$f"; then sha256sum "$f"; else echo "missing $f"; fi
done
"""
IDENTITY = 'cat /sys/class/net/br-lan/address; cat /proc/sys/kernel/random/boot_id\n'
TEMP = '''umask 077
d=$(mktemp -d /tmp/schoolbell-fresh.XXXXXX)
trap 'rm -rf "$d"' EXIT
'''

def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def load_bundle(root, target):
    doc=json.loads((root/'bundle/manifest.json').read_bytes())
    if (doc['openwrt'],doc['target'],doc['architecture']) != ('19.07.9','ramips/mt76x8','mipsel_24kc'):
        raise ValueError('Wrong fresh-install runtime')
    rows=doc['packages']; names=set(); files=set()
    for r in rows:
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.+-]*\.ipk',r['file']) or r['file'] in files or r['name'] in names:
            raise ValueError('Unsafe/duplicate bundle entry')
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9+_.-]*',r['name']): raise ValueError('Invalid package name')
        if r['architecture'] not in ('all','mipsel_24kc') or digest(root/'bundle'/r['file'])!=r['sha256']:
            raise ValueError('Damaged/incompatible package '+r['file'])
        if r['bytes']!=(root/'bundle'/r['file']).stat().st_size or r['file_blocks_estimate']<1:
            raise ValueError('Invalid package size')
        names.add(r['name']);files.add(r['file'])
    byname={r['name']:r for r in rows}
    if len(rows)!=35 or byname['modbus-schoolbell']['sha256']!=target['sha256'] or byname['modbus-schoolbell']['version']!=target['version'] or byname['modbus-schoolbell-clock']['version']!='1.0.0':
        raise ValueError('Incomplete fresh-install bundle')
    return rows

def inventory(raw):
    result={}
    for line in raw.splitlines():
        name,sep,version=line.partition(' - ')
        if not sep or not name or not version or name in result: raise ValueError('Invalid package inventory')
        result[name]=version
    return result

def plan(rows, installed):
    missing=[]
    for r in rows:
        old=installed.get(r['name'])
        if old is None: missing.append(r)
        elif old!=r['version'] and old!=STOCK.get(r['name']):
            raise ValueError('Unsupported installed dependency '+r['name']+' '+old)
    return missing

def space(rows):
    flash=(sum(r['file_blocks_estimate'] for r in rows)+512*1024+1023)//1024
    ram=(sum(r['bytes'] for r in rows)+1023)//1024+4096
    return 'test "$(df -k /overlay | awk \'END {print $4}\')" -ge '+str(flash)+'\ntest "$(df -k /tmp | awk \'END {print $4}\')" -ge '+str(ram)+'\n'

def read_backup(raw):
    if len(raw)>MAX_BACKUP_BYTES: raise ValueError('Backup too large')
    header,sep,blob=raw.partition(b'\n')
    if not sep or not re.fullmatch(rb'[0-9a-f]{64}  [^\r\n]+',header) or header[:64].decode()!=hashlib.sha256(blob).hexdigest(): raise ValueError('Backup checksum mismatch')
    with tarfile.open(fileobj=io.BytesIO(blob)) as t:
        expected=['identity.txt','inventory.txt','overlay.tar','protected.txt']
        if sorted(t.getnames())!=expected or any(not m.isfile() or m.size>MAX_BACKUP_BYTES for m in t.getmembers()): raise ValueError('Invalid backup contents')
        parts={n:t.extractfile(n).read() for n in expected}
    with tarfile.open(fileobj=io.BytesIO(parts['overlay.tar'])) as t:
        for m in t.getmembers():
            if m.isfile():
                f=t.extractfile(m)
                while f.read(65536): pass
    return blob,parts

def prepare(args, root, manifest, remote, base, emit):
    rows=load_bundle(root,manifest['package'])
    # Keep a verified base image beside the backup for reflash + overlay recovery.
    image=root/'firmware/tp_recovery.bin'
    expected_image=RECOVERY_SHA
    if digest(image)!=expected_image: raise ValueError('Missing verified OpenWrt recovery image')
    emit('Чистая OpenWrt: сохраняем конфигурацию и список пакетов. Запись пакетов ещё не началась.')
    command=base+FRESH+TEMP
    command+='overlay_kib=$(du -sk /overlay | awk \'{print $1}\')\ncase "$overlay_kib" in \'\'|*[!0-9]*) exit 1;; esac\n'
    command+='test "$(df -k /tmp | awk \'END {print $4}\')" -ge "$((overlay_kib * 2 + 6144))"\n'
    command+='{ '+IDENTITY+'} > "$d/identity.txt"\n{ '+PROTECTED+'} > "$d/protected.txt"\n'
    command+='opkg list-installed | sort > "$d/inventory.txt"\ntar -C /overlay -cf "$d/overlay.tar" .\n'
    command+='{ '+PROTECTED+'} > "$d/after.txt"\ncmp "$d/protected.txt" "$d/after.txt"\n'
    command+='opkg list-installed | sort > "$d/inventory-after.txt"\ncmp "$d/inventory.txt" "$d/inventory-after.txt"\n'
    command+='tar -C "$d" -cf "$d/backup.tar" identity.txt inventory.txt overlay.tar protected.txt\nsha256sum "$d/backup.tar"\ncat "$d/backup.tar"\n'
    blob,parts=read_backup(remote(command,stdout=-1).stdout)
    installed=inventory(parts['inventory.txt'].decode());missing=plan(rows,installed)
    if 'modbus-schoolbell' in installed: raise ValueError('Not a fresh installation')
    identity=parts['identity.txt'].decode().strip().splitlines()
    if len(identity)!=2: raise ValueError('Invalid device identity')
    remote(base+FRESH+space(missing),stdout=-1)
    state=Path(args.session)
    (state/'backup.tar').write_bytes(blob);(state/'overlay.tar').write_bytes(parts['overlay.tar'])
    shutil.copy2(image,state/'openwrt-recovery.bin')
    data={'mode':'fresh','manifest':manifest,'source':args.source,'index':args.index,'created':time.time(),
          'identity':identity,'inventory':installed,'protected':parts['protected.txt'].decode(),
          'rows':rows,'missing':missing,'backup_sha256':digest(state/'backup.tar'),
          'overlay_sha256':digest(state/'overlay.tar'),'recovery_sha256':expected_image}
    (state/'prepared.json').write_text(json.dumps(data),encoding='utf8')
    emit('BACKUP VERIFIED. Новая установка: '+', '.join(r['name']+' '+r['version'] for r in missing))
    emit('Копия и образ восстановления сохранены. Откат: та же OpenWrt через Reset, затем восстановление overlay; автоматически не выполняется.')

def evidence(state,data):
    for name,key in [('backup.tar','backup_sha256'),('overlay.tar','overlay_sha256'),('openwrt-recovery.bin','recovery_sha256')]:
        if digest(state/name)!=data[key]: raise ValueError('Corrupt fresh-install recovery evidence')

def resume(args,root,data,remote,base,snapshot,emit):
    state=Path(args.session);evidence(state,data)
    if (data['source'],data['index'])!=(args.source,args.index): raise ValueError('Different connection')
    binding='test "$(cat /sys/class/net/br-lan/address)" = '+shlex.quote(data['identity'][0])+'\ntest "$(cat /proc/sys/kernel/random/boot_id)" = '+shlex.quote(data['identity'][1])+'\n'
    protected='{ '+PROTECTED+'} > "$d/protected.txt"\nprintf \'%s\' '+shlex.quote(data['protected'])+' > "$d/expected.txt"\ncmp "$d/protected.txt" "$d/expected.txt"\n'
    command=base+binding+TEMP+protected
    payload=None
    if args.action=='install':
        if time.time()-data['created']>1800: raise ValueError('Preparation expired')
        if (state/'write-started').exists(): raise ValueError('Unknown outcome; verify first')
        if load_bundle(root,data['manifest']['package'])!=data['rows']: raise ValueError('Bundle changed')
        command+=FRESH+space(data['missing'])
        old=''.join(n+' - '+v+'\n' for n,v in sorted(data['inventory'].items()))
        command+="LC_ALL=C opkg list-installed | LC_ALL=C sort > \"$d/inventory.txt\"\nprintf '%s  %s\\n' "+shlex.quote(hashlib.sha256(old.encode()).hexdigest())+" \"$d/inventory.txt\" | sha256sum -c -\n"
        payload=io.BytesIO()
        with tarfile.open(fileobj=payload,mode='w',format=tarfile.USTAR_FORMAT) as t:
            for r in data['missing']: t.add(root/'bundle'/r['file'],arcname=r['file'],recursive=False)
            checks=''.join(r['sha256']+'  '+r['file']+'\n' for r in data['missing']).encode()
            info=tarfile.TarInfo('SHA256SUMS');info.size=len(checks);t.addfile(info,io.BytesIO(checks))
        payload.seek(0)
        command+='cd "$d"\ntar xf -\nsha256sum -c SHA256SUMS\nopkg install '+ ' '.join(shlex.quote('./'+r['file']) for r in data['missing'])+'\n'
        (state/'write-started').write_text('Fresh installation attempt '+uuid.uuid4().hex)
    command+="while read name version; do test \"$(opkg status \"$name\" | sed -n 's/^Version: //p')\" = \"$version\" || exit 1; done <<'SCHOOLBELL_VERSIONS'\n"
    for r in data['rows']:
        expected=data['inventory'].get(r['name'],r['version'])
        command+=r['name']+' '+expected+'\n'
    command+='SCHOOLBELL_VERSIONS\n'
    command+='test ! -e /etc/schoolbell-editor/package.pending\n'+snapshot+protected+'/etc/init.d/schoolbell-auto running\n/etc/init.d/uhttpd running\necho GUI_FRESH_VERIFIED\n'
    result=remote(command,input=payload.getvalue(),stdout=-1) if payload else remote(command,stdout=-1)
    if not result.stdout.rstrip().endswith(b'GUI_FRESH_VERIFIED'): raise ValueError('Fresh result proof missing')
    (state/'verified.json').write_text(json.dumps({'version':data['manifest']['package']['version'],
        'time':time.time(),'prepared_sha256':digest(state/'prepared.json'),'marker_sha256':digest(state/'write-started')}))
    emit('FRESH VERIFIED. Школьник установлен, службы работают, автозвонки выключены. Сеть и часы не изменялись.')


def unchanged(data,remote,base):
    """Prove the exact pre-install state; absence of the application alone is insufficient."""
    inventory_text=''.join(n+' - '+v+'\n' for n,v in sorted(data['inventory'].items()))
    command=base+FRESH+TEMP
    command+='test "$(cat /sys/class/net/br-lan/address)" = '+shlex.quote(data['identity'][0])+'\n'
    command+='test "$(cat /proc/sys/kernel/random/boot_id)" = '+shlex.quote(data['identity'][1])+'\n'
    command+='LC_ALL=C opkg list-installed | LC_ALL=C sort > "$d/inventory.txt"\n'
    command+="printf '%s  %s\\n' "+shlex.quote(hashlib.sha256(inventory_text.encode()).hexdigest())+' "$d/inventory.txt" | sha256sum -c -\n'
    command+='{ '+PROTECTED+'} > "$d/protected.txt"\n'
    command+="printf '%s' "+shlex.quote(data['protected'])+' > "$d/expected.txt"\ncmp "$d/protected.txt" "$d/expected.txt"\n'
    command+='echo GUI_UNCHANGED_VERIFIED\n'
    result=remote(command,stdout=-1)
    if not result.stdout.rstrip().endswith(b'GUI_UNCHANGED_VERIFIED'):
        raise ValueError('Unchanged-state proof missing')
