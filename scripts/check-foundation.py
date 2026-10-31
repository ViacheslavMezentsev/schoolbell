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
    assert item['status'] in ('not-transferred', 'transferred')
    if item['status'] == 'transferred': assert (root / item['destination']).is_file()
assert 'pkg/usr/lib/modbus/json_strict.lua' in seen
for path in root.rglob('*.md'):
    if any(part in ('.git', 'out', 'build') for part in path.relative_to(root).parts): continue
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
        if '://' in target or target.startswith('#'): continue
        assert (path.parent / target.split('#')[0]).exists(), (path, target)
mapping = json.loads((root / 'docs/source-map.json').read_text())
destinations = set()
for item in mapping['files']:
    path = item['destination']
    assert path not in destinations
    destinations.add(path)
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == item['destination_sha256'], path
    if 'prose_sha256' in item:
        prose = re.sub(r'(\[[^\]]*\]\()([^\)]+)(\))', lambda m: m[1] + 'LINK' + m[3], (root / path).read_text())
        assert hashlib.sha256(prose.encode()).hexdigest() == item['prose_sha256'], path
for language in ('README.md', 'README.en.md'):
    index = (root / 'docs' / language).read_text()
    for item in mapping['files']:
        if item['source'].startswith('docs/packages/schoolbell/'):
            assert '(' + item['destination'][5:] + ')' in index, (language, item['destination'])
print('PASS: legacy archive, source map, preserved prose, complete document maps and local Markdown links')
