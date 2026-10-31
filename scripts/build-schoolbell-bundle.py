#!/usr/bin/env python3
"""Assemble an offline release directory. No target access, install or publication."""
import argparse, json, pathlib, shutil, subprocess, tempfile, re, urllib.request
from schoolbell_ipk import read, sha, closure, check_directories
ROOT=pathlib.Path(__file__).resolve().parents[1]
def build(lock_path,schoolbell,native,core,cache,out,download=False):
    lock=json.loads(pathlib.Path(lock_path).read_text());out=pathlib.Path(out);cache=pathlib.Path(cache)
    if out.exists():raise ValueError('output must be a new directory')
    cache.mkdir(parents=True,exist_ok=True);inputs=[];metas={};entries=[]
    for item in lock['packages']:
        name=item['filename']
        if pathlib.Path(name).name!=name or not name.endswith('.ipk'):raise ValueError('filename')
        path=cache/name
        if not path.exists():
            if not download:raise ValueError('missing cached IPK: '+name+' (explicit --download required)')
            if not item['url'].startswith('https://downloads.openwrt.org/releases/19.07.9/'):raise ValueError('source')
            with urllib.request.urlopen(item['url'],timeout=60) as response:
                raw=response.read(item['bytes']+1)
            if len(raw)!=item['bytes']:raise ValueError('download size')
            temporary=cache/(name+'.part');temporary.write_bytes(raw)
            if sha(temporary)!=item['sha256']:temporary.unlink();raise ValueError('download SHA256')
            temporary.replace(path)
        if path.stat().st_size!=item['bytes'] or sha(path)!=item['sha256']:raise ValueError('cached SHA256: '+name)
        inputs.append((path,'dependency',item))
    inputs.extend([(pathlib.Path(schoolbell),'schoolbell',None),(pathlib.Path(native),'native',None)])
    if core is not None: inputs.append((pathlib.Path(core),'core',None))
    filenames=set()
    for path,role,pin in inputs:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.+-]*\.ipk',path.name) or path.name in filenames:raise ValueError('duplicate/unsafe IPK filename')
        filenames.add(path.name)
        meta,control,data=read(path);name=meta['Package']
        if name in metas:raise ValueError('duplicate package')
        if meta['Architecture'] not in ('all',lock['architecture']):raise ValueError('architecture')
        if pin and any(meta[k]!=pin[v] for k,v in [('Package','name'),('Version','version'),('Architecture','architecture')]):raise ValueError('pinned metadata')
        if pin and meta.get('Depends','')!=pin['depends']:raise ValueError('pinned dependencies')
        if role in ('schoolbell','native'):check_directories(path)
        if role=='schoolbell':
            if name!='modbus-schoolbell' or not {'preinst','postinst','prerm'}<=set(control) or 'usr/sbin/schoolbell-auto' not in data:raise ValueError('complete schoolbell required')
        if role=='core' and name!='modbus-rtu-core':raise ValueError('core required')
        if role=='native':
            elf=data.get('usr/lib/lua/schoolbell/clock_linux.so',(b'',0))[0]
            if name!='modbus-schoolbell-clock' or elf[:7]!=b'\x7fELF\x01\x01\x01' or elf[18:20]!=b'\x08\x00':raise ValueError('MIPS little-endian native required')
        metas[name]=meta
        # Uncompressed file data plus block rounding, not compressed feed Installed-Size.
        payload=sum(len(v[0]) for v in data.values());blocks=sum(max(4096,((len(v[0])+4095)//4096)*4096) for v in data.values())
        entries.append({'name':name,'version':meta['Version'],'architecture':meta['Architecture'],'role':role,'file':path.name,'sha256':sha(path),'bytes':path.stat().st_size,'payload_bytes':payload,'file_blocks_estimate':blocks,'depends':meta.get('Depends',''),'source':pin['url'] if pin else 'project build','license':pin['license'] if pin else 'see project notices'})
    closure(metas,lock['firmware'])
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=ROOT))
    manifest={'format':1,'openwrt':lock['openwrt'],'target':lock['target'],'architecture':lock['architecture'],'firmware':lock['firmware'],'source_commit':commit,'source_dirty':dirty,'provenance_note':'Commit identifies assembly source; supplied IPK hashes identify exact inputs, not a signed build attestation.','packages':entries,'download_bytes':sum(x['bytes'] for x in entries),'payload_bytes':sum(x['payload_bytes'] for x in entries),'file_blocks_estimate':sum(x['file_blocks_estimate'] for x in entries),'hardware_validated':False}
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.schoolbell-bundle-',dir=out.parent) as temporary:
        stage=pathlib.Path(temporary)/'release';stage.mkdir()
        for path,_,_ in inputs:shutil.copyfile(path,stage/path.name)
        (stage/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        shutil.copyfile(lock_path,stage/'dependencies.lock.json')
        for lang in ('md','en.md'):
            guide=(ROOT/('docs/PACKAGING.'+lang)).read_text().replace('(PACKAGING.md)','(README.md)').replace('(PACKAGING.en.md)','(README.en.md)')
            (stage/('README.'+lang)).write_text(guide)
        shutil.copyfile(ROOT/'packaging/offline/check.sh',stage/'check.sh')
        (stage/'SHA256SUMS').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted(stage.iterdir()) if p.is_file()))
        stage.rename(out)
    print(json.dumps({k:manifest[k] for k in ('source_commit','source_dirty','download_bytes','payload_bytes','file_blocks_estimate')},indent=2))
    return manifest
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lock',type=pathlib.Path,default=ROOT/'packaging/offline/openwrt-19.07.9-mipsel_24kc.json')
    for k in ('schoolbell','native','out'):p.add_argument('--'+k,required=True,type=pathlib.Path)
    p.add_argument('--core',type=pathlib.Path,help='optional separately supplied core IPK')
    p.add_argument('--cache',type=pathlib.Path,default=ROOT/'out/offline-cache');p.add_argument('--download',action='store_true');a=p.parse_args()
    build(a.lock,a.schoolbell,a.native,a.core,a.cache,a.out,a.download)
