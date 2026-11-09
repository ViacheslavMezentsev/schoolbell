"""Build an offline stock-recovery kit from repository-pinned vendor archives."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile
from firmware import prepare_oem
from build import PYTHON_SHA

HERE = Path(__file__).resolve().parent
OEM_ZIP_SHA = 'c01e8ad8c882ee2cc5dbb2899111f111c37aa356d366f0b6098f6c5f139bacea'
NAME = 'mr3020-eu-v3.30-stock-recovery'

def checked(path, digest):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError('Archive hash mismatch: ' + path.name)
    return data

def build(dest, vendor=HERE / 'vendor'):
    # SETUP_RECOVERY_SPEC 3.9: no downloads, devices, or unpinned firmware.
    import io
    runtime = checked(vendor / 'python-3.11.9-embed-amd64.zip', PYTHON_SHA)
    source = checked(vendor / 'tl-mr3020-eu-v3.30-250625.zip', OEM_ZIP_SHA)
    with zipfile.ZipFile(io.BytesIO(source)) as archive:
        bins = [n for n in archive.namelist() if n.lower().endswith('.bin')]
        if len(bins) != 1:
            raise ValueError('Expected exactly one OEM BIN')
        payload = prepare_oem(archive.read(bins[0]))
    dest.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest) as temp:
        root = Path(temp) / NAME
        (root / 'firmware').mkdir(parents=True)
        (root / 'firmware/oem-recovery.bin').write_bytes(payload)
        with zipfile.ZipFile(io.BytesIO(runtime)) as archive:
            archive.extractall(root / 'python')  # Exact pinned upstream archive.
        with (root / 'python/python311._pth').open('a') as paths:
            paths.write('\n..\n')
        for name in ('Setup.cmd', 'Setup.ps1', 'tftp_server.py', 'firmware.py'):
            shutil.copyfile(HERE / name, root / name)
        (root / 'Recovery.cmd').write_bytes(b'@echo off\r\ncall "%~dp0Setup.cmd" -RestoreFactory %*\r\nexit /b %errorlevel%\r\n')
        shutil.copyfile(HERE / 'RECOVERY.md', root / 'README.md')
        shutil.copytree(vendor, root / 'vendor', ignore=shutil.ignore_patterns('python-3.11.9-embed-amd64.zip'))
        files = sorted(f for f in root.rglob('*') if f.is_file())
        (root / 'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest() + '  ' + f.relative_to(root).as_posix() + '\n' for f in files))
        target = Path(temp) / (NAME + '.zip')
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in files + [root / 'SHA256SUMS']:
                archive.write(file, NAME + '/' + file.relative_to(root).as_posix())
        target.replace(dest / target.name)
        checksum = hashlib.sha256((dest / target.name).read_bytes()).hexdigest()
        (dest / (target.name + '.sha256')).write_text(checksum + '  ' + target.name + '\n')
        print(dest / target.name)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dest', type=Path, default=HERE / 'dist')
    build(parser.parse_args().dest)
