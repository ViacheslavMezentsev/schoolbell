"""Verify migration metadata and the immutable legacy snapshot; no hardware."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
archive = root / 'docs/archive/schoolbell-4'
manifest = json.loads((archive / 'manifest.json').read_text())
assert len(manifest['files']) == 20
expected = {'README.md', 'README.en.md', 'manifest.json'}
for item in manifest['files']:
    path = item['path']
    assert not Path(path).is_absolute() and '..' not in Path(path).parts
    data = (archive / path).read_bytes()
    assert len(data) == item['bytes'], path
    assert hashlib.sha256(data).hexdigest() == item['sha256'], path
    expected.add(path)
assert {str(p.relative_to(archive)) for p in archive.rglob('*') if p.is_file()} == expected
inventory = json.loads((root / 'docs/migration-inventory.json').read_text())
seen = set()
for item in inventory['files']:
    assert item['source'] not in seen
    seen.add(item['source'])
    assert re.fullmatch('[a-f0-9]{64}', item['sha256'])
    assert item['status'] == 'not-transferred'
assert 'pkg/usr/lib/modbus/json_strict.lua' in seen
for path in root.rglob('*.md'):
    if '.git' in path.parts: continue
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
        if '://' in target or target.startswith('#'): continue
        assert (path.parent / target.split('#')[0]).exists(), (path, target)
print('PASS: 20 archived files, inventory and local Markdown links')
