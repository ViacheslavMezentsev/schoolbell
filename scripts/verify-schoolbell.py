#!/usr/bin/env python3
"""Verify pinned media and complete and historical preview schoolbell IPKs (no extraction)."""
import hashlib
import json
import re
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
media = root / 'assets/melodies'
manifest = json.loads((media / 'manifest.json').read_text())
for item in manifest['files']:
    data = (media / item['path']).read_bytes()
    assert len(data) == item['bytes'], item['path'] + ': size mismatch'
    assert hashlib.sha256(data).hexdigest() == item['sha256'], item['path'] + ': SHA256 mismatch'
sample = (media / 'test.mp3').read_bytes()
source_sample = root / 'packaging/openwrt/package/usr/share/modbus-schoolbell/melodies/test.mp3'
assert source_sample.read_bytes() == sample, 'package source differs from pinned sample'
out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'out'
packages = list(out.glob('modbus-schoolbell_*.ipk'))
assert packages, 'schoolbell IPK missing'
from schoolbell_ipk import read, check_directories
from license_materials import verify_package
current_version=re.search(r"^Version: (.+)$",(root/"packaging/openwrt/package/CONTROL/control").read_text(),re.M)[1]
for package in packages:
    meta,control,data=read(package)
    if 'usr/sbin/schoolbell-auto' not in data:
        assert set(control)=={'control'}, 'invalid historical preview'
        assert set(data)=={'usr/share/modbus-schoolbell/NOTICE','usr/share/modbus-schoolbell/melodies/test.mp3'}
        assert tuple(map(int,meta['Version'].split('.'))) < (5,0,28), 'current package cannot be preview'
    else:
        check_directories(package)
        if meta["Version"] == current_version:
            verify_package(data, "schoolbell")
        # Check literal runtime dependencies from the actual archive, not source files.
        for path, (body, mode) in data.items():
            if not (path.endswith('.lua') or path.startswith('usr/sbin/')):
                continue
            for module in re.findall(rb"require\s*\(\s*['\"](schoolbell\.[a-z_]+)['\"]", body):
                name=module.decode().replace('.', '/')
                if name=='schoolbell/clock_linux':
                    assert 'modbus-schoolbell-clock (= 1.0.0)' in meta['Depends']
                    continue
                assert any(base+name+'.lua' in data for base in ('usr/lib/lua/', 'usr/share/schoolbell-editor/lua/')), (path, 'missing runtime module', name)

        assert set(control)=={'control','preinst','postinst','prerm'}
        assert 'modbus-schoolbell-clock (= 1.0.0)' in meta['Depends']
        assert data['usr/share/schoolbell-editor/VERSION'][0].decode().strip()==meta['Version']
        assert all(not n.startswith(('etc/schoolbell-editor/','etc/modbus-schoolbell/')) for n in data), 'owned user data'
        for name in ('etc/init.d/schoolbell-auto','usr/sbin/schoolbell-auto','usr/sbin/schoolbell-package'):
            assert data[name][1]&0o111, name
        for name in ('test','0','1','2','3','4'):
            assert data['usr/share/schoolbell-sound-test/'+name+'.mp3'][0]==(media/(name+'.mp3')).read_bytes()
        for name in ('preinst','postinst','prerm'):assert control[name][1]&0o111
    print('[schoolbell] pinned media and IPK payload OK:',package.name)
