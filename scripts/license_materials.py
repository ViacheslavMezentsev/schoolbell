"""Deterministic, offline license delivery and evidence reporting; no legal clearance."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PREFIXES = {'schoolbell': 'usr/share/modbus-schoolbell/',
            'native': 'usr/share/modbus-schoolbell-clock/'}


def materials(component):
    if component not in ('schoolbell', 'native', 'pages', 'bundle'):
        raise ValueError('unknown license component')
    sources = {'LICENSE': ROOT / 'LICENSE', 'NOTICE': ROOT / 'NOTICE',
               'LICENSE-SCOPE.txt': ROOT / 'packaging/licenses/SCOPE.txt'}
    if component != 'native':
        sources['AUDIO-NOTICE.txt'] = ROOT / 'packaging/openwrt/package/usr/share/modbus-schoolbell/NOTICE'
        sources['media-manifest.json'] = ROOT / 'assets/melodies/manifest.json'
    if component in ('pages', 'bundle'):
        sources['LUCI-LICENSE'] = ROOT / 'site/LUCI-LICENSE'
        sources['portable-zones.NOTICE'] = ROOT / 'site/portable-zones.NOTICE'
    return {name: path.read_bytes() for name, path in sources.items()}


def package_files(component):
    return {PREFIXES[component] + name: (body, 0o644)
            for name, body in materials(component).items()}


def verify_package(data, component):
    for name, (body, mode) in package_files(component).items():
        if data.get(name) != (body, mode):
            raise ValueError('missing/stale license material: ' + name)


def write_materials(directory, component):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for name, body in materials(component).items():
        (directory / name).write_bytes(body)


def checksums(directory):
    directory = Path(directory)
    return ''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' +
                   p.relative_to(directory).as_posix() + '\n'
                   for p in sorted(directory.rglob('*'))
                   if p.is_file() and p != directory / 'SHA256SUMS')


def dependency_evidence(meta, data, pin, role, digest):
    notices = sorted(n for n in data if any(k in n.lower()
                     for k in ('license', 'copying', 'notice', 'copyright')))
    return {'name': meta['Package'], 'version': meta['Version'], 'role': role,
            'sha256': digest, 'license_in_control': meta.get('License'),
            'license_in_lock': pin.get('license') if pin else None,
            'binary_url': pin.get('url') if pin else None,
            'source_recipe_in_control': meta.get('Source'),
            'notice_named_payload_paths': notices,
            'notice_scan_scope': 'filenames only; inline notices not exhaustively reviewed',
            'distribution_cleared': False,
            'missing': ['Exact corresponding sources, patches and build configuration',
                        'Component-specific copyright notices and license texts',
                        'Review of precise license versions, exceptions and delivery obligations']}


def write_dependency_report(directory, evidence, firmware):
    report = {'format': 1, 'distribution_cleared': False, 'firmware_requirements': firmware,
              'scope': 'Supplied dependency/core IPKs; own-code MIT does not relicense them',
              'packages': evidence,
              'known_source_evidence': {
                  p['name']: 'Apache-2.0 header in LuCI 712bc8e52d73720dc42577c08eb80ce7b1548b1e libs/luci-lib-jsonc/src/jsonc.c; not a replacement for missing binary License metadata'
                  for p in evidence if p['name'] == 'luci-lib-jsonc' and
                  p['sha256'] == '89c089284941775f1d7b36226ad8c9ebba3bf94ae86106c3e9a504fba2ebff39'},
              'limitations': ['This is not a complete license/corresponding-source kit',
                              'Firmware libc/kernel and audio rights require separate review']}
    directory = Path(directory)
    (directory / 'DEPENDENCIES.json').write_text(json.dumps(report, indent=2) + '\n')
    (directory / 'DEPENDENCIES.txt').write_text(
        'DEPENDENCY EVIDENCE / СВЕДЕНИЯ О ЗАВИСИМОСТЯХ\n\n'
        'distribution_cleared=false. See DEPENDENCIES.json for exact inputs and gaps.\n'
        'Binary URLs and Source recipe paths are not complete corresponding sources.\n'
        'Нет полного комплекта исходников, текстов лицензий и атрибуций зависимостей.\n'
        'JSON содержит версии/хеши, исходные поля и открытые вопросы по каждому IPK.\n\n' +
        ''.join(p['name'] + ' ' + p['version'] + ': control License=' +
                str(p['license_in_control']) + '; lock=' + str(p['license_in_lock']) + '\n'
                for p in evidence))
