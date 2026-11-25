#!/usr/bin/env python3
"""Validate the release pair and write public checksums; no upload or signing."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

def manifest(path):
    with zipfile.ZipFile(path) as archive:
        names=[n for n in archive.namelist() if n.count('/')==1 and n.endswith('/manifest.json')]
        if len(names)!=1:
            raise ValueError('Expected one root manifest')
        if len(archive.namelist()) != len(set(archive.namelist())):
            raise ValueError('Duplicate ZIP entries')
        root=names[0].split('/')[0]+'/'
        expected={}
        for line in archive.read(root+'SHA256SUMS').decode().splitlines():
            sha,name=line.split('  ',1)
            if name in expected or name.startswith('/') or '..' in Path(name).parts:
                raise ValueError('Unsafe or duplicate checksum entry')
            expected[name]=sha
        files={n[len(root):] for n in archive.namelist() if n.startswith(root) and n!=root+'SHA256SUMS'}
        if files!=set(expected) or len(archive.namelist())!=len(expected)+1:
            raise ValueError('Unlisted ZIP contents')
        for name,sha in expected.items():
            if hashlib.sha256(archive.read(root+name)).hexdigest()!=sha:
                raise ValueError('ZIP checksum mismatch')
        return json.loads(archive.read(names[0]))

def finalize(directory):
    directory=Path(directory)
    wizards=list(directory.glob('schoolbell-setup-wizard-v*-windows-x86_64.zip'))
    packages=list(directory.glob('schoolbell-v*-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip'))
    if len(wizards)!=1 or len(packages)!=1:
        raise ValueError('Expected exactly one wizard and one package ZIP')
    wizard, package=manifest(wizards[0]),manifest(packages[0])
    if wizard['kind']!='schoolbell-setup-wizard' or package['kind']!='schoolbell-package-bundle':
        raise ValueError('Wrong archive kind')
    if wizard['package_bundle_format']!=package['format']:
        raise ValueError('Incompatible bundle formats')
    version=lambda v: tuple(int(n) for n in v.split('.'))
    if version(wizard['version']) < version(package['wizard']['minimum_version']):
        raise ValueError('Wizard too old')
    if wizard['source_commit']!=package['assembly_commit']:
        raise ValueError('Different assembly commits')
    ipk='modbus-schoolbell_'+package['version']+'_all.ipk'
    app=[r for r in package['packages'] if r['name']=='modbus-schoolbell']
    if len(app)!=1 or hashlib.sha256((directory/ipk).read_bytes()).hexdigest()!=app[0]['sha256']:
        raise ValueError('Standalone IPK differs from ZIP package')
    paths=wizards+packages+[directory/ipk, directory/'target-build.json']
    if any(not f.is_file() or f.is_symlink() for f in paths):
        raise ValueError('Missing or linked artifact')
    expected={p.name for p in paths}|{'SHA256SUMS','release-pair.json'}
    if {p.name for p in directory.iterdir()}-expected:
        raise ValueError('Unexpected release directory contents')
    pair={'format':1,'status':'prerelease','commit':wizard['source_commit'],
          'wizard':wizards[0].name,'packages':packages[0].name,
          'compatibility':'format checked; exact pair requires acceptance',
          'hardware_validated':False,'published':False}
    (directory/'release-pair.json').write_text(json.dumps(pair,indent=2)+'\n')
    paths.append(directory/'release-pair.json')
    (directory/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(paths)))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',required=True,type=Path)
    finalize(parser.parse_args().directory)
