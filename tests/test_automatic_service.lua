-- Execute the actual infinite worker with injected host clock/storage/player I/O.
package.loaded['schoolbell.clock_mailbox']={system=function()return {process=function()end}end}
local witness,invalidations
package.loaded['schoolbell.automatic_status']={invalidate=function()witness=nil;invalidations=invalidations+1 end,publish=function(raw,status,boot)assert(type(raw)=='string' and type(status)=='table' and type(boot)=='string');witness={raw=raw,status=status,boot=boot}end}
local C=require('schoolbell.media_codec');local Store=require('schoolbell.automatic_store')
local Sound=dofile('packaging/openwrt/root/usr/lib/lua/schoolbell/sound_test.lua')
local realopen,realtime=io.open,os.time
local native=os.getenv('SCHOOLBELL_CHILD')=='1' and require('nixio') or nil
local t=assert(os.time({year=2026,month=10,day=25,hour=8,min=0,sec=0}))
local function scenario(name,opts)
 witness=nil;invalidations=0
 local now,up=opts.initial_utc or t-1,100;local plays,claims,checkpoints=0,0,0;local raw,status,last;local active={enabled=true,generation=1,watermark=t-1,boot='boot',zone='UTC',revision='r',plan={}}
 local waits,kills=0,0
 if opts.disabled then active.enabled=false end
 if opts.stored_zone then active.zone=opts.stored_zone end
 if opts.watermark then active.watermark=opts.watermark end
 local audits={}
 local function publish()local body=C.encode(active);raw=C.encode({data=active,checksum=C.sha(body)})end;publish()
 local fakeClaim=function()end
 local fake={root='/unused',environment=function()return {now=now,date='2026-10-25',boot=opts.reboot and 'newboot' or 'boot',zone='UTC'}end,
 raw=function()return raw end,decode=function()return C.decode(raw).data end,
 prepare_claim=Store.prepare_claim,on_boot=function()end,claim=fakeClaim,advance=function()end,transaction=function(operation,generation,utc)
  if operation==package.loaded['schoolbell.journal'].record_boot then return {ok=true}end
  if generation=='newboot' then active.enabled=false;active.generation=active.generation+1;publish();return {ok=true,state=C.decode(raw).data,raw=raw}end
  if operation~=fakeClaim then checkpoints=checkpoints+1;active.watermark=math.max(active.watermark,utc);publish();return {ok=true,state=C.decode(raw).data,raw=raw}end
  claims=claims+1;if opts.fail then return {ok=false}end
  assert(generation==active.generation and (utc==t or (opts.swap and utc==t+2)));active.watermark=now;publish();if opts.claim_step then now=now+10 end;return {ok=true,state=C.decode(raw).data,raw=raw}
 end}
 local originalEvents=require('schoolbell.automatic').events
 require('schoolbell.automatic').events=function()return opts.idle and {} or opts.swap and {{utc=t,media='test'},{utc=t+2,media='0'}} or {{utc=t,media='test'}}end
 package.loaded['schoolbell.automatic_store']=fake
 package.loaded['schoolbell.controls']={snapshot=function()return {ok=true,muted=opts.muted or false}end}
 package.loaded['schoolbell.journal']={record_boot=function()end,request=function(_,action)audits[#audits+1]=action;return {ok=true}end}
 package.loaded['schoolbell.sound_test']={system=function()return {muted=function()return false end,ready=function()return not opts.swap or now>=t+2 end,acquire=function()if opts.acquire_step then now=now+10 end;return not opts.busy end,release=function()return true end,spawn=function()plays=plays+1;if native then local pid=native.fork();if pid==0 then native.exec('/bin/sleep','1');os.exit(127)end;return pid end;return 42 end,wait=function(pid)waits=waits+1;if opts.play_wait and waits<=5 then return false end;if native then return native.waitpid(pid,'nohang')end;return 42,'exited',0 end,sleep=function()if opts.play_wait then up=up+1;now=now+1;if opts.wait_step and waits==2 then now=now+10 end end;if native then native.nanosleep(0,100000000)end end,kill=function(pid)kills=kills+1;if native then return native.kill(pid,9)end;error('unexpected kill')end}end,run=Sound.run}
 local rounds=0
 package.loaded['nixio']={open=function()return {lock=function()return true end}end,nanosleep=function()
  rounds=rounds+1;if rounds>=4 then error('finished fixture')end
  now=opts.jump and t+60+rounds or now+(opts.slow and 4 or 1);up=up+(opts.slow and 4 or 1)
 end}
 package.loaded['nixio.fs']={lstat=function(path)assert(path=='/unused/package.pending');return opts.package_pending and {type='reg'} or nil end,rename=function()last=status;return true end}
 os.time=function()return now end
 io.open=function(path,mode)
  if path=='/proc/uptime'then return {read=function()return tostring(up)..' 0' end,close=function()return true end}end
  if path=='/tmp/schoolbell-auto-status.next'then return {write=function(_,v)status=assert(C.decode(v));return true end,close=function()return true end}end
  error('unexpected file '..path..' '..tostring(mode))
 end
 local ok,err=pcall(dofile,'packaging/openwrt/root/usr/sbin/schoolbell-auto')
 assert(not ok and tostring(err):find('finished fixture'),tostring(err))
 io.open=realopen;os.time=realtime;require('schoolbell.automatic').events=originalEvents
 assert(invalidations==1,'startup invalidation')
 if opts.package_pending then assert(witness==nil,'unvalidated startup published')else assert(witness and witness.raw==raw and C.encode(witness.status)==C.encode(last),'witness not bound to checked bytes');assert(witness.boot==(opts.reboot and 'newboot' or 'boot'))end
 assert(plays==(opts.expected or 0),name..' plays '..plays)
 assert(claims==(opts.claims or ((opts.package_pending or opts.reboot or opts.idle) and 0 or 1)),name..' claims '..claims)
 if opts.idle then assert(checkpoints==(opts.jump and 2 or 1),name..' repeated flash writes '..checkpoints)end
 assert(last and ((opts.package_pending and last.state=='executor_error') or (not opts.package_pending and last.state~='executor_error')),name..' executor error')
 if opts.swap then assert(table.concat(audits,','):find('auto_requested,auto_audio_unavailable,auto_requested,auto_ok',1,true),'missing per-event journal') end
 if opts.state then assert(last.state==opts.state,name..' state '..tostring(last.state))end
 print('PASS worker '..name)
end
scenario('unfinished package never claims or plays',{package_pending=true})
scenario('normal once, durable before spawn',{expected=1})
scenario('mute never plays',{muted=true})
scenario('busy never requeues',{busy=true})
scenario('claim failure never plays',{fail=true})
scenario('forward jump never plays',{jump=true})
scenario('reboot requires confirmation',{reboot=true})
scenario('slow idle loops never recursively checkpoint',{idle=true,slow=true})
scenario('forward wall-clock jump checkpoints once',{idle=true,jump=true})
scenario('hot replacement uses next due event; no toggle or replay',{swap=true,claims=2,expected=1,state='running'})
scenario('slow claim expires a bell without stopping the service',{claim_step=true})
scenario('slow media acquire expires before fork',{acquire_step=true})
scenario('running player survives wall clock step',{play_wait=true,wait_step=true,expected=1})
scenario('new boot is stopped',{reboot=true,state='disabled'})
scenario('same-boot restart continues',{expected=1,state='running'})
scenario('disabled plan stays disabled',{disabled=true,claims=0,state='disabled'})
scenario('stored timezone mismatch remains visible',{stored_zone='OTHER',claims=0,state='timezone_changed'})
scenario('invalid calendar blocks invalid dates',{initial_utc=100,claims=0,state='clock_invalid'})
scenario('durable future watermark forbids replay',{watermark=t+60,claims=0,state='backward_hold'})
package.loaded['schoolbell.automatic_store']=Store
