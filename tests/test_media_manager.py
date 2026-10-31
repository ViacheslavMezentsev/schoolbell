"""Real Linux process crashes at every commit checkpoint; no audio."""
from pathlib import Path
import os, subprocess, sys, shutil, hashlib
root, build = map(Path, sys.argv[1:])
lua = shutil.which('lua5.1')
script = root/'tests/test_media_manager.lua'
sources = [root/'assets/melodies/test.mp3', root/'assets/melodies/0.mp3']
def call(folder, mode, point='-', expected=0):
    result = subprocess.run([lua, str(script), str(folder), mode, point, *map(str,sources)], capture_output=True, text=True, timeout=30)
    if result.returncode != expected:
        raise AssertionError((mode, point, result.returncode, result.stdout, result.stderr))
    return result.stdout

def fresh(name):
    p=build/name;p.mkdir(mode=0o700);return p
for length in [0, 3, 55, 56, 63, 64, 65, 1000, 16384]:
    text = bytes(i % 256 for i in range(length))
    lua_code = "local c=require('schoolbell.media_codec');local t={};for i=0,"+str(length-1)+" do t[#t+1]=string.char(i%256) end;print(c.sha(table.concat(t)))"
    output = subprocess.check_output([lua, '-e', lua_code], text=True, timeout=30).strip()
    assert output == hashlib.sha256(text).hexdigest(), length
print('PASS independent hashlib oracle: 9 padding/binary/boundary vectors')
p=fresh('basic');print(call(p,'basic'),end='');print(call(p,'unsafe'),end='')
p=fresh('negative');print(call(p,'negative'),end='')
p=fresh('discover');call(p,'init');output=call(p,'run');points=next(x[7:] for x in output.splitlines() if x.startswith('POINTS\t')).split(',');print(call(p,'verify'),end='')
for i,point in enumerate(points):
    p=fresh('crash'+str(i));call(p,'init');call(p,'crash',point,77);call(p,'verify')
    shutil.rmtree(p)
    print('PASS process crash:',point,flush=True)
print('PASS media manager:',len(points),'process-crash checkpoints; real fsync/rename, no power-loss claim')
