"""OS-owned lease. Persistent file is never removed (avoids inode races)."""
import contextlib
import json
import os
from pathlib import Path
import uuid

@contextlib.contextmanager
def lease(folder):
    path=Path(str(folder)+'.lease')
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('a+b') as f:
        if path.stat().st_size==0:
            f.write(b'0');f.flush()
        f.seek(0)
        try:
            if os.name=='nt':
                import msvcrt
                msvcrt.locking(f.fileno(),msvcrt.LK_NBLCK,1)
            else:
                import fcntl
                fcntl.flock(f.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        except OSError as exc:
            raise ValueError('Сеанс занят другим процессом. Дождитесь его завершения.') from exc
        try: yield
        finally:
            f.seek(0)
            if os.name=='nt': msvcrt.locking(f.fileno(),msvcrt.LK_UNLCK,1)
            else: fcntl.flock(f.fileno(),fcntl.LOCK_UN)

def marker(path):
    # The lease must be held before creating or recovering these markers.
    with path.open('x',encoding='utf8') as f:
        json.dump({'format':1,'lease':'os-lock-v1'},f)
        f.flush();os.fsync(f.fileno())

def recover(folder):
    paths=[Path(str(folder)+'.guard'),folder/'operation.lock',folder/'zip-session.guard']
    existing=[p for p in paths if p.exists()]
    for p in existing:
        if p.is_symlink() or p.stat().st_size>1024:
            raise ValueError('Неизвестная блокировка: требуется ручная диагностика.')
        try: value=json.loads(p.read_text())
        except (ValueError,UnicodeError): value=None
        if value!={'format':1,'lease':'os-lock-v1'}:
            raise ValueError('Блокировка старой версии: требуется ручная диагностика.')
    if existing:
        archive=folder.parent/'recovery-history'/uuid.uuid4().hex
        archive.mkdir(parents=True)
        for p in existing: p.rename(archive/p.name)
    # Never remove transaction markers or claim that a device write succeeded.
    return 'uncertain' if any((folder/p).exists() for p in ('write-started','zip-session/write-started')) else 'error'
