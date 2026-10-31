"""Read bounded IPK metadata without extracting paths or running hooks."""
import hashlib, io, pathlib, re, tarfile
MAX_IPK=16*1024*1024
NAME=re.compile(r'[a-z0-9][a-z0-9+.-]*')
def fields(raw):
    result={}
    for line in raw.decode().splitlines():
        if not line or line[0].isspace():continue
        k,v=line.split(':',1)
        if k in result:raise ValueError('duplicate field: '+k)
        result[k]=v.strip()
    return result
def archive(raw):
    result={};total=0
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as t:
        for m in t:
            name=m.name[2:] if m.name.startswith('./') else m.name
            if name in ('','.') or m.isdir():continue
            if name.startswith('/') or '..' in name.split('/') or name in result:raise ValueError('unsafe/duplicate archive path')
            total+=m.size
            if total>64*1024*1024:raise ValueError('archive size')
            if m.isfile():result[name]=(t.extractfile(m).read(),m.mode)
            elif m.issym():result[name]=(b'',m.mode)
            else:raise ValueError('unsupported archive entry')
    return result

def read(path):
    path=pathlib.Path(path)
    if path.stat().st_size>MAX_IPK:raise ValueError('IPK too large')
    raw=path.read_bytes();outer=archive(raw)
    if set(outer)!={'debian-binary','control.tar.gz','data.tar.gz'} or outer['debian-binary'][0]!=b'2.0\n':raise ValueError('IPK format')
    control=archive(outer['control.tar.gz'][0]);data=archive(outer['data.tar.gz'][0]);meta=fields(control['control'][0])
    if not NAME.fullmatch(meta['Package']):raise ValueError('package name')
    return meta,control,data

def dependencies(text):
    result=[]
    for v in text.split(','):
        if not v.strip():continue
        m=re.fullmatch(r'\s*([a-z0-9][a-z0-9+.-]*)(?:\s*\(=\s*([^ ()]+)\))?\s*',v)
        if not m:raise ValueError('unsupported dependency expression: '+v)
        result.append(m.groups())
    return result

def closure(packages,baseline):
    for name,meta in packages.items():
        for dep,version in dependencies(meta.get('Depends','')):
            actual=packages.get(dep,{}).get('Version',baseline.get(dep))
            if actual is None or (version and actual!=version):raise ValueError('unsatisfied '+name+' -> '+dep)

def sha(path):return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def check_directories(path):
    """opkg requires explicit parent directory entries, unlike Python extraction."""
    outer=archive(pathlib.Path(path).read_bytes())
    with tarfile.open(fileobj=io.BytesIO(outer['data.tar.gz'][0]),mode='r:gz') as t:
        directories={'.'}
        for member in t:
            name=member.name[2:] if member.name.startswith('./') else member.name
            if member.isdir():directories.add(name.rstrip('/'))
            else:
                for parent in pathlib.PurePosixPath(name).parents:
                    if str(parent) not in directories:raise ValueError('missing preceding directory: '+str(parent))
