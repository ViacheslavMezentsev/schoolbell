"""Read-only pre-flash backup of OpenWrt overlay and every MTD partition."""
import hashlib
import io
import json
from pathlib import Path
import re
import shlex
import tarfile
import time
import uuid

def read_checked(raw):
    header,sep,blob=raw.partition(b'\n')
    if not sep or not re.fullmatch(b'[0-9a-f]{64}  [^\r\n]+',header): raise ValueError('Missing backup checksum')
    if hashlib.sha256(blob).hexdigest()!=header.split()[0].decode(): raise ValueError('Backup checksum mismatch')
    return blob

def backup(args, remote, base, snapshot, emit):
    # A unique directory never replaces an earlier recovery copy.
    folder=Path(args.session)/('firmware-backup-'+time.strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8])
    folder.mkdir()
    identity=remote(base+snapshot+'echo GUI_IDENTITY\ncat /sys/class/net/br-lan/address\ncat /proc/sys/kernel/random/boot_id\n',stdout=-1).stdout.decode()
    before,sep,identity_tail=identity.partition('GUI_IDENTITY\n')
    ids=identity_tail.strip().splitlines()
    if not sep or len(ids)!=2: raise ValueError('Device identity missing')
    bind='test "$(cat /sys/class/net/br-lan/address)" = '+shlex.quote(ids[0])+'\ntest "$(cat /proc/sys/kernel/random/boot_id)" = '+shlex.quote(ids[1])+'\n'
    table=remote(base+bind+'cat /proc/mtd\n',stdout=-1).stdout.decode()
    parts=[]
    for line in table.splitlines()[1:]:
        m=re.fullmatch(r'(mtd\d+): ([0-9a-fA-F]{8}) [0-9a-fA-F]{8} "([^"\r\n]+)"',line)
        if not m: raise ValueError('Unexpected MTD table')
        parts.append((m[1],int(m[2],16),m[3]))
    if not parts or len(parts)>16 or sum(p[1] for p in parts)>32*1024*1024: raise ValueError('Unexpected MTD layout')
    files={}
    for name,size,label in parts:
        emit('Чтение резервной копии раздела '+name+' ('+label+')...')
        raw=remote(base+bind+'sha256sum /dev/'+name+'\ncat /dev/'+name+'\n',stdout=-1).stdout
        blob=read_checked(raw)
        if len(blob)!=size: raise ValueError('MTD size differs')
        filename=name+'.bin';(folder/filename).write_bytes(blob);files[filename]=hashlib.sha256(blob).hexdigest()
    command=base+bind+'''umask 077
test "$(df -k /tmp | awk 'END {print $4}')" -ge 4096
d=$(mktemp -d /tmp/schoolbell-backup.XXXXXX)
trap 'rm -rf "$d"' EXIT
tar -C /overlay -cf "$d/overlay.tar" .
sha256sum "$d/overlay.tar"
cat "$d/overlay.tar"
'''
    blob=read_checked(remote(command,stdout=-1).stdout)
    with tarfile.open(fileobj=io.BytesIO(blob)) as archive:
        for m in archive.getmembers():
            if m.isfile():
                f=archive.extractfile(m)
                while f.read(65536): pass
    (folder/'overlay.tar').write_bytes(blob);files['overlay.tar']=hashlib.sha256(blob).hexdigest()
    after=remote(base+bind+snapshot,stdout=-1).stdout.decode()
    if before!=after: raise ValueError('Sound or plan changed during backup')
    for name,expected in files.items():
        if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=expected: raise ValueError('Local backup mismatch')
    proof={'identity':ids,'mtd':parts,'files':files,'created':time.time(),'source':args.source,'index':args.index}
    (folder/'verified.json').write_text(json.dumps(proof),encoding='utf8')
    emit('DEVICE BACKUP VERIFIED. Копия overlay и '+str(len(parts))+' разделов MTD проверена; звук и план сохранены. Каталог: '+str(folder))
