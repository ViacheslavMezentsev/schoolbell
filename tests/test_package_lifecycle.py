#!/usr/bin/env python3
"""TC-134: real hooks in a translated temporary root, real Lua/FS, fake procd.
This is NOT target opkg or a power-cut test. No audio/network/hardware calls.
"""
import io, os, pathlib, re, subprocess, sys, tempfile, tarfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from schoolbell_ipk import read
sys.path.insert(0,str(ROOT/'scripts'))
import importlib.util
spec=importlib.util.spec_from_file_location('builder',ROOT/'scripts/build-schoolbell.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
with tempfile.TemporaryDirectory(prefix='schoolbell-package-') as tmp:
    base=pathlib.Path(tmp);target=base/'target';target.mkdir();(target/'etc').mkdir();(target/'tmp').mkdir()
    ipk=builder.build(base/'out');meta,hooks,files=read(ipk)
    with tarfile.open(ipk) as outer:
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile('./data.tar.gz').read())) as payload:
            directories={'.'}
            for member in payload:
                name=member.name[2:] if member.name.startswith('./') else member.name
                if member.isdir():directories.add(name.rstrip('/'))
                else:
                    for parent in pathlib.PurePosixPath(name).parents:
                        assert str(parent) in directories, 'opkg requires earlier directory entry: '+str(parent)
    print('PASS archive explicitly defines every parent directory before files')
    def translate(s):
        return re.sub(r'/etc/|/tmp/|/usr/sbin/|/usr/share/',lambda m:str(target)+m.group(),s)
    def unpack(payload):
        for name,(data,mode) in payload.items():
            p=target/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);p.chmod(mode)
        # Only procd is replaced; its operations are recorded, not performed.
        p=target/'etc/init.d/schoolbell-auto'
        p.write_text('#!/bin/sh\nprintf "%s\\n" "$1" >> "'+str(base/'service.log')+'"\n');p.chmod(0o755)
    shim=base/'shim.lua'
    shim.write_text(r"""
local root=assert(arg[1]);local action=assert(arg[2]);local H=require('schoolbell.media_fs_host')
local oldsync=H.sync;local oldspace=H.space
H.sync=function(path)if H.stat(root..'/fail-sync')then return nil end;return oldsync(path)end
H.space=function(path)if H.stat(root..'/fail-space')then return 0,10485760 end;return oldspace(path)end
local FS=require('schoolbell.media_fs');local original=FS.new
FS.new=function(path)return original(path,H)end
local st=function(p)local v=H.stat(p);if v then v.modedec=tonumber(string.format('%o',v.mode))end;return v end
package.loaded['nixio.fs']={lstat=st,mkdir=H.mkdir,unlink=H.unlink,rmdir=H.rmdir}
package.loaded.nixio={open=function(path)return {sync=function()return H.sync(path)end,close=function()return true end}end}
local Store=require('schoolbell.automatic_store');Store.root=root..'/etc/schoolbell-editor'
if action=='seed'then
 local fs=FS.new(Store.root);local S=require('schoolbell.schedule_store');local C=require('schoolbell.media_codec')
 local d=S.empty();d.mode='fixed';d.fixed_schedule='s';d.schedules={{id='s',name='Fixture',rows={{id='r',time='08:00',media='test',enabled=true,pre=false}}}}
 local v=S.save(fs,C.encode(d),'empty');assert(v.ok)
 local e={now=1792886400,date='2026-10-25',boot='fixture',zone='UTC',resolve=function()return {1792890000}end}
 assert(Store.change(fs,true,v.revision,e).enabled);fs.close();os.exit(0)
elseif action=='disabled'then assert(not Store.decode(Store.raw()).enabled);os.exit(0)
end
arg={action};dofile(root..'/usr/sbin/schoolbell-package.lua')
""")
    def lua(action,good=True):
        q=subprocess.run(['lua5.1',str(shim),str(target),action],capture_output=True,text=True)
        assert (q.returncode==0)==good,(action,q.stdout,q.stderr)
    # Model the target PATH: stat must never be called; lua uses native host lstat.
    tools=base/'bin';tools.mkdir()
    (tools/'stat').write_text('#!/bin/sh\necho forbidden-stat >&2\nexit 127\n');(tools/'stat').chmod(0o755)
    (tools/'lua').write_text('#!/bin/sh\nexec lua5.1 "$@"\n');(tools/'lua').chmod(0o755)
    preload=base/'nixio.lua';preload.write_text("local H=require('schoolbell.media_fs_host');package.loaded['nixio.fs']={lstat=function(p)local s=H.stat(p);if s then s.modedec=tonumber(string.format('%o',s.mode))end;return s end}")
    def hook(name,good=True,offline=False):
        p=base/name;p.write_text(translate(hooks[name][0].decode()))
        env=os.environ.copy();env['PATH']=str(tools)+':'+env['PATH'];env['LUA_INIT']='@'+str(preload)
        if offline:env['IPKG_INSTROOT']=str(target)
        q=subprocess.run(['sh',str(p)],env=env,capture_output=True,text=True)
        assert (q.returncode==0)==good,(name,q.stdout,q.stderr)
    def helpers():
        p=target/'usr/sbin/schoolbell-package.lua';p.write_text(translate(files['usr/sbin/schoolbell-package'][0].decode()))
        p=target/'usr/sbin/schoolbell-package';p.write_text('#!/bin/sh\nexec lua5.1 "'+str(shim)+'" "'+str(target)+'" "$1"\n');p.chmod(0o755)
    # Offline image hooks never execute target code or touch the host/root.
    for name in hooks:
        if name!='control':hook(name,offline=True)
    assert not (base/'service.log').exists() and not (target/'etc/schoolbell-editor').exists()
    cache=target/'tmp/luci-modulecache';cache.mkdir()
    ours=cache/'7363686F6F6C62656C6C2E636C6F636B5F6D61696C626F78';ours.write_text('old schoolbell bytecode')
    other=cache/'6C7563692E64697370617463686572';other.write_text('unrelated cache')
    (target/'etc/modbus-schoolbell').mkdir(mode=0o755) # Existing public parent; private data child is required.
    hook('preinst');unpack(files);helpers();hook('postinst');lua('disabled')
    assert (base/'service.log').read_text().splitlines()==['enable','start']
    assert not ours.exists() and other.read_text()=='unrelated cache'
    print('PASS package bytecode invalidated; unrelated LuCI modules retained')
    print('PASS fresh package, offline hooks, disabled startup')
    lua('seed')
    user=target/'etc/modbus-schoolbell/data/user.mp3';user.write_bytes(b'user-melody-fixture')
    clock=target/'etc/schoolbell-editor/clock-reference.json';clock.write_bytes(b'preserved-device-reference')
    schedule=target/'etc/schoolbell-editor/schedule.json'
    # Snapshot actual user files except mutable automatic state and lock.
    def saved():return {str(p.relative_to(target)):p.read_bytes() for p in (target/'etc').rglob('*') if p.is_file() and not str(p).endswith(('automatic.json','.lock','package.pending')) and 'init.d' not in str(p)}
    before=saved()
    mailbox=target/'tmp/schoolbell-clock-control';mailbox.mkdir(mode=0o700)
    (mailbox/'request.json').write_text('queued enable from old process')
    (mailbox/'result.json').write_text('old result')
    (mailbox/'metrics.json').write_text('old metrics')
    (mailbox/'metrics.next').write_text('unfinished metrics')
    # Upgrade and rollback with deliberately distinguishable code revisions.
    for label in ('fixture-upgrade','fixture-rollback'):
        hook('prerm');hook('preinst')
        pending=target/'etc/schoolbell-editor/package.pending';assert pending.exists()
        unpack(files);helpers();(target/'usr/share/schoolbell-editor/VERSION').write_text(label)
        hook('postinst');lua('disabled');assert saved()==before
        assert not (mailbox/'request.json').exists() and not (mailbox/'result.json').exists()
        assert not (mailbox/'metrics.json').exists() and not (mailbox/'metrics.next').exists()
        assert not pending.exists();assert not (target/'tmp/schoolbell-sound-test.lock').exists()
    print('PASS upgrade/rollback retain draft, melody and clock reference; auto-off')
    # Refuse foreign gates and private-root symlinks; do not clear somebody else's lock.
    lock=target/'tmp/schoolbell-sound-test.lock';lock.mkdir();(lock/'foreign').write_text('keep')
    hook('preinst',good=False);assert (lock/'foreign').read_text()=='keep'
    (lock/'foreign').unlink();lock.rmdir()
    private=target/'etc/modbus-schoolbell/data';renamed=private.with_name('data-saved');private.rename(renamed);private.symlink_to(renamed)
    hook('preinst',good=False);private.unlink();renamed.rename(private)
    private.chmod(0o777);hook('preinst',good=False);private.chmod(0o700)
    print('PASS missing stat, foreign lock, symlink and unsafe permissions refusal')
    # Corrupt state: postinst fails closed, no enable/start, no fallback that activates.
    hook('preinst');auto=target/'etc/schoolbell-editor/automatic.json';old=auto.read_bytes();auto.write_text('corrupt')
    calls=(base/'service.log').read_bytes();hook('postinst',good=False)
    assert calls==(base/'service.log').read_bytes();assert (target/'etc/schoolbell-editor/package.pending').exists()
    lua('initialize',good=False)
    auto.write_bytes(old)
    # Simulate tmpfs loss only; pending marker remains and finish reacquires its gate.
    (lock/'package-owner').unlink();lock.rmdir();hook('postinst');lua('disabled')
    assert saved()==before
    print('PASS interrupted finish/retry and lost tmpfs; data preserved')
    for fault in ('fail-sync','fail-space'):
        hook('preinst');flag=target/fault;flag.write_text('fault')
        calls=(base/'service.log').read_bytes();hook('postinst',good=False)
        assert calls==(base/'service.log').read_bytes() and (target/'etc/schoolbell-editor/package.pending').exists()
        flag.unlink();hook('postinst');lua('disabled');assert saved()==before
    print('PASS sync failure and ENOSPC reserve refusal; explicit retry remains auto-off')
print('PASS host lifecycle harness (target opkg and power-loss validation pending)')
