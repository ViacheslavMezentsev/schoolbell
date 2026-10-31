-- Execute the actual infinite worker with injected host clock/storage/player I/O.
package.loaded['schoolbell.clock_mailbox']={system=function()return {process=function()end}end}
local witness,invalidations
package.loaded['schoolbell.automatic_status']={invalidate=function()witness=nil;invalidations=invalidations+1 end,publish=function(raw,status,boot)assert(type(raw)=='string' and type(status)=='table' and type(boot)=='string');witness={raw=raw,status=status,boot=boot}end}
local C=require('schoolbell.media_codec');local Store=require('schoolbell.automatic_store')
local Sound=dofile('packaging/openwrt/root/usr/lib/lua/schoolbell/sound_test.lua')
local Gate=require('schoolbell.clock_gate');local Reference=require('schoolbell.clock_reference')
local realopen,realtime=io.open,os.time
local native=os.getenv('SCHOOLBELL_CHILD')=='1' and require('nixio') or nil
local t=assert(os.time({year=2026,month=10,day=25,hour=8,min=0,sec=0}))
local function scenario(name,opts)
 witness=nil;invalidations=0
 local now,up=opts.initial_utc or t-1,100;local plays,claims,checkpoints=0,0,0;local raw,status,last;local active={enabled=true,generation=1,watermark=t-1,boot='boot',zone='UTC',revision='r',plan={}}
 local saved,clock_reads,waits,kills=nil,0,0,0
 if opts.disabled then active.enabled=false end
 if opts.stored_zone then active.zone=opts.stored_zone end
 if opts.watermark then active.watermark=opts.watermark end
 local loaded={ok=true,revision='empty'}
 if opts.reference_offset then
  loaded.data={format='schoolbell-clock/1',source='manual',confirmed_utc_ms=(t-1+opts.reference_offset)*1000,checkpoint_utc_ms=(t-1+opts.reference_offset)*1000}
  local _,hash=Reference.encode(loaded.data);loaded.revision=hash
 end
 if opts.reference_fail then loaded={ok=false} end
 local clockio={valid_utc=function()return true end,clock=function()clock_reads=clock_reads+1;return {utc_ms=now*1000,before_ms=up*1000,after_ms=up*1000,context=opts.context or 'boot'}end,store={load=function()return loaded end,save=function(v)local _,hash=Reference.encode(v);saved=v;return {ok=true,revision=hash}end}}
 local gate=Gate.new(function()if opts.unavailable then error('missing adapter')end;return clockio end,{enforced=opts.enforced or false})
 if opts.confirmed then local q=assert(gate.request_confirmation());assert(gate.confirm(q.token,false).ok)end
 package.loaded['schoolbell.clock_gate']={system=function()return gate end}
 local function publish()local body=C.encode(active);raw=C.encode({data=active,checksum=C.sha(body)})end;publish()
 local fakeClaim=function()end
 local fake={root='/unused',environment=function()return {now=now,date='2026-10-25',boot=opts.reboot and 'newboot' or 'boot',zone='UTC'}end,
 raw=function()return raw end,decode=function()return C.decode(raw).data end,
 claim=fakeClaim,advance=function()end,transaction=function(operation,generation,utc)
  if operation~=fakeClaim then checkpoints=checkpoints+1;active.watermark=math.max(active.watermark,utc);publish();return {ok=true,state=C.decode(raw).data,raw=raw}end
  claims=claims+1;if opts.fail then return {ok=false}end
  assert(generation==active.generation and (utc==t or (opts.late_confirm and utc==t+2)));active.watermark=now;publish();if opts.claim_step then now=now+10 end;return {ok=true,state=C.decode(raw).data,raw=raw}
 end}
 local originalEvents=require('schoolbell.automatic').events
 require('schoolbell.automatic').events=function()return opts.idle and {} or opts.late_confirm and {{utc=t,media='test'},{utc=t+2,media='0'}} or {{utc=t,media='test'}}end
 package.loaded['schoolbell.automatic_store']=fake
 package.loaded['schoolbell.controls']={snapshot=function()return {ok=true,muted=opts.muted or false}end}
 package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
 package.loaded['schoolbell.sound_test']={system=function()return {muted=function()return false end,ready=function()return true end,acquire=function()if opts.acquire_step then now=now+10 end;return not opts.busy end,release=function()return true end,spawn=function()plays=plays+1;if native then local pid=native.fork();if pid==0 then native.exec('/bin/sleep','1');os.exit(127)end;return pid end;return 42 end,wait=function(pid)waits=waits+1;if opts.play_wait and waits<=5 then return false end;if native then return native.waitpid(pid,'nohang')end;return 42,'exited',0 end,sleep=function()if opts.play_wait then up=up+1;now=now+1;if opts.wait_step and waits==2 then now=now+10 end end;if native then native.nanosleep(0,100000000)end end,kill=function(pid)kills=kills+1;if native then return native.kill(pid,9)end;error('unexpected kill')end}end,run=Sound.run}
 local rounds=0
 package.loaded['nixio']={open=function()return {lock=function()return true end}end,nanosleep=function()
  rounds=rounds+1;if rounds>=4 then error('finished fixture')end
  now=opts.jump and t+60+rounds or now+(opts.slow and 4 or 1);up=up+(opts.slow and 4 or 1)
  if opts.late_confirm and rounds==2 then local q=assert(gate.request_confirmation());assert(gate.confirm(q.token,false).ok);active.generation=2;publish()end
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
 assert(claims==(opts.claims or ((opts.package_pending or opts.reboot or opts.idle or (opts.enforced and not opts.confirmed and not opts.late_confirm)) and 0 or 1)),name..' claims '..claims)
 if opts.idle then assert(checkpoints==(opts.jump and 2 or 1),name..' repeated flash writes '..checkpoints)end
 assert(last and ((opts.package_pending and last.state=='executor_error') or (not opts.package_pending and last.state~='executor_error')),name..' executor error')
 if opts.enforced and not opts.confirmed and not opts.late_confirm then assert(checkpoints==0,'untrusted UTC persisted as watermark')end
 if opts.enforced then assert(last.clock_trust.enforced and clock_reads>0 or opts.unavailable);if opts.blocked then assert(not last.clock_trust.automatic_permitted)end end
 if opts.confirmed then assert(last.clock_trust.confirmed_utc==t-1 and last.clock_trust.confirmed_utc_ms==nil,'status seconds')end
 if opts.play_wait then assert(kills==0,'clock trust must not interrupt current sound');assert(clock_reads>=5,'no observations while waiting')end
 if opts.state then assert(last.state==opts.state,name..' state '..tostring(last.state))end
 if opts.reason then assert(last.clock_trust.reason==opts.reason,name..' reason '..tostring(last.clock_trust.reason))end
 if opts.no_writes then assert(saved==nil and checkpoints==0,name..' unexpected persistent write')end
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
scenario('unconfirmed clock consumes due bell without playing',{enforced=true,blocked=true})
scenario('confirmed clock allows normal bell',{enforced=true,confirmed=true,expected=1})
scenario('missing clock adapter fails closed',{enforced=true,unavailable=true,blocked=true})
scenario('clock step after durable claim blocks spawn',{enforced=true,confirmed=true,claim_step=true,blocked=true})
scenario('clock step during media acquire blocks spawn',{enforced=true,confirmed=true,acquire_step=true,blocked=true})
scenario('clock observed throughout player wait',{enforced=true,confirmed=true,play_wait=true,expected=1})
scenario('trust loss during wait does not interrupt child',{enforced=true,confirmed=true,play_wait=true,wait_step=true,expected=1,blocked=true})
scenario('late confirmation and explicit activation never replay missed bell',{enforced=true,late_confirm=true,expected=1})
-- AC-06 / TC-132: new worker instance, retained persisted state, synthetic boot/UTC.
scenario('same boot restart retains reference but never restores trust',{enforced=true,reference_offset=0,blocked=true,state='clock_untrusted',reason='startup',no_writes=true})
scenario('future reference detects rollback after startup',{enforced=true,reference_offset=60,blocked=true,state='clock_untrusted',reason='before_reference',no_writes=true})
scenario('unreadable persisted reference blocks startup',{enforced=true,reference_fail=true,blocked=true,state='clock_untrusted',reason='reference_unavailable',no_writes=true})
scenario('cold boot blocks even with control disabled',{reboot=true,state='confirm_clock',no_writes=true})
scenario('stored timezone mismatch blocks even with bypass',{stored_zone='OTHER',claims=0,state='timezone_changed',no_writes=true})
scenario('confirmation cannot bypass boot mismatch',{enforced=true,confirmed=true,reboot=true,state='confirm_clock'})
scenario('confirmation cannot bypass stored timezone mismatch',{enforced=true,confirmed=true,stored_zone='OTHER',claims=0,state='timezone_changed'})
scenario('disabled plan stays disabled after confirmation',{enforced=true,confirmed=true,disabled=true,claims=0,state='disabled'})
scenario('invalid calendar blocks even with bypass',{initial_utc=100,claims=0,state='clock_invalid'})
scenario('same boot explicit bypass may resume future bells',{expected=1,state='running'})
scenario('durable future watermark forbids replay with bypass',{watermark=t+60,claims=0,state='backward_hold'})
package.loaded['schoolbell.clock_gate']=Gate
package.loaded['schoolbell.automatic_store']=Store
