local Store=require('schoolbell.automatic_store');local S=require('schoolbell.schedule_store');local C=require('schoolbell.media_codec')
local host=os.getenv('MEDIA_HOST')=='1' and require('schoolbell.media_fs_host') or nil
local fs=require('schoolbell.media_fs').new(assert(arg[1]),host)
local d=S.empty();d.fixed_schedule='s';d.schedules={{id='s',name='Fixture',rows={{id='r',time='08:00',media='test',enabled=true,pre=false}}}}
local saved=S.save(fs,C.encode(d),'empty');assert(saved.ok)
local env={now=1792886400,date='2026-10-25',boot='fixture',zone='UTC',resolve=function()return {1792890000}end}
local active=Store.change(fs,true,saved.revision,env);assert(active.enabled)
local claim=Store.claim(fs,active.generation,env.now+60,env.now+60);assert(claim.watermark==env.now+60)
fs.close();fs=require('schoolbell.media_fs').new(arg[1],host)
assert(Store.decode(fs.read(Store.name,Store.max_bytes)).watermark==env.now+60)
assert(not pcall(Store.claim,fs,active.generation,env.now+60,env.now+60))
local stopped=Store.change(fs,false,nil,env);assert(not stopped.enabled)
assert(S.load(fs).revision==saved.revision);fs.close()
print('PASS automatic native filesystem: activation, fsync claim, reopen, duplicate refusal, disable, draft unchanged')
