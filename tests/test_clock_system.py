import os, pathlib, subprocess, sys, tempfile
root=pathlib.Path(sys.argv[1]); script=root/'tests/test_clock_system.lua'
def run(path,mode='normal'):
    subprocess.run(['lua5.1',str(script),str(path),mode],check=True,timeout=20)
with tempfile.TemporaryDirectory(prefix='schoolbell-clock-') as work:
    work=pathlib.Path(work)
    def directory(name):
        p=work/name;p.mkdir(mode=0o700);return p
    run(directory('normal'))
    p=directory('orphan');(p/'clock-reference.next').write_text('unfinished');(p/'clock-reference.next').chmod(0o600);run(p,'orphan')
    for kind in ('symlink','hardlink','fifo','oversize','public-file','corrupt'):
        p=directory(kind);f=p/'clock-reference.json';outside=work/(kind+'-outside');outside.write_text('untouched');outside.chmod(0o600)
        if kind=='symlink': f.symlink_to(outside)
        elif kind=='hardlink': os.link(outside,f)
        elif kind=='fifo': os.mkfifo(f,0o600)
        else: f.write_text('x'*1025 if kind=='oversize' else 'invalid');f.chmod(0o644 if kind=='public-file' else 0o600)
        run(p,'load-fail');assert outside.read_text()=='untouched'
    for name in ('.clock-reference.lock','clock-reference.next'):
        p=directory('link-'+name);outside=work/('outside-'+name);outside.write_text('safe');outside.chmod(0o600);(p/name).symlink_to(outside)
        if name.startswith('.'):run(p,'open-fail')
        else:
            run(p,'save-fail')
        assert outside.read_text()=='safe'
    p=directory('public');p.chmod(0o755);run(p,'open-fail')
    p=directory('parent');(work/'linked-parent').symlink_to(p,target_is_directory=True);run(work/'linked-parent','open-fail')
    p=directory('locked')
    child=subprocess.Popen(['lua5.1',str(script),str(p),'lock'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    try:
        assert child.stdout.readline().strip()=='locked';run(p,'open-fail')
    finally: child.communicate('\n',timeout=5)
    assert child.returncode==0
    run(p)
print('clock system: hostile file types, private roots and cross-process lock PASS')
