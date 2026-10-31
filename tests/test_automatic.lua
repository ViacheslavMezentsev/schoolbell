local A=require('schoolbell.automatic');local S=require('schoolbell.schedule_store')
local C=require('schoolbell.media_codec');local Store=require('schoolbell.automatic_store')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS automatic '..name)end
local events={{utc=100,media='test'},{utc=160,media='0'}}
test('startup skips the current/past instant',function()local e=A.new(100,0,0);assert(not e.step(101,1,events,false))end)
test('one admission, bounded lateness, no repeat',function()local e=A.new(99,0,0);assert(e.step(101,2,events,false).utc==100);assert(not e.step(102,3,events,false))end)
test('mute skip remains consumed after unmute',function()local e=A.new(99,0,0);local v,why=e.step(100,1,events,true);assert(v.utc==100 and why=='muted');assert(not e.step(101,2,events,false))end)
test('forward jump never catches up',function()local e=A.new(99,0,0);local v,why=e.step(161,1,events,false);assert(v.utc==160 and why=='clock_gap');assert(not e.step(162,2,events,false))end)
test('backward jump preserves high water',function()local e=A.new(159,0,0);assert(e.step(160,1,events,false));assert(not e.step(99,2,events,false));assert(not e.step(100,3,events,false))end)
test('durable watermark across restart and rollback',function()local e=A.new(90,0,160);assert(not e.step(100,1,events,false))end)
test('long processing gap and expiry',function()local e=A.new(99,0,0);local v,why=e.step(103,4,events,false);assert(v.utc==100 and why=='clock_gap');assert(not e.step(104,5,events,false))end)
local d=S.empty();d.fixed_schedule='s';d.schedules={{id='s',name='School',rows={{id='r',time='08:00',media='1',enabled=true,pre=true}}}}
local resolver=function(_,t)return {t=='08:00' and 200 or 80}end
test('fixed and pre melody',function()local e=assert(A.events(d,'2026-10-25',resolver));assert(#e==2 and e[1].media=='test' and e[2].media=='1')end)
test('annual missing year/date stays quiet',function()d.mode='annual';assert(#assert(A.events(d,'2026-10-25',resolver))==0);d.mode='fixed'end)
test('annual explicit date and no repeated year',function()d.mode='annual';d.plans={{year=2026,schedule_ids={'s'},days='A'..string.rep('.',364)}};assert(#assert(A.events(d,'2026-01-01',resolver))==2);assert(#assert(A.events(d,'2027-01-01',resolver))==0);d.mode='fixed';d.plans=nil end)
test('named range resolves across years and leaves gaps quiet',function()
 d.mode='annual';d.plans={{id='academic',name='School year',start='2026-12-31',["end"]='2027-01-01',schedule_ids={'s'},days='AA'}}
 assert(#assert(A.events(d,'2026-12-31',resolver))==2);assert(#assert(A.events(d,'2027-01-01',resolver))==2)
 assert(#assert(A.events(d,'2027-01-02',resolver))==0);d.mode='fixed';d.plans=nil
end)
test('gap fold and simultaneous times reject day',function()local e,why=A.events(d,'2026-10-25',function()return {}end);assert(not e and why=='nonexistent_time');e,why=A.events(d,'2026-10-25',function()return {1,2}end);assert(not e and why=='ambiguous_time');e,why=A.events(d,'2026-10-25',function()return {1}end);assert(not e and why=='simultaneous_events')end)
test('libc roundtrip and DST',function()
 local e=A.resolve('2026-01-01','08:00');assert(#e==1)
 if os.getenv('TZ')=='Europe/Berlin' then assert(#A.resolve('2026-03-29','02:30')==0);assert(#A.resolve('2026-10-25','02:30')==2)end
end)
local files={};local fail_at;local steps=0
local function op()steps=steps+1;if steps==fail_at then error('fault')end end
local fs={read=function(p)return files[p]end,stat=function(p)return files[p] and {}end,space=function()return 10000000,12000000 end,
 write=function(p,v)op();files[p]=v end,sync=function()op()end,rename=function(a,b)op();files[b]=files[a];files[a]=nil end,unlink=function(p)files[p]=nil end}
local draft=assert(S.save(fs,C.encode(d),'empty'));assert(draft.ok)
local env={now=1792886400,date='2026-10-25',boot='boot',zone='UTC',resolve=resolver}
test('explicit revision activation and durable claim',function()
 assert(not pcall(Store.change,fs,true,'wrong',env));assert(Store.decode(nil).enabled==false)
 local active=Store.change(fs,true,draft.revision,env);assert(active.enabled and active.revision==draft.revision)
 assert(not pcall(Store.claim,fs,active.generation+1,env.now+60,env.now+60))
 local claimed=Store.claim(fs,active.generation,env.now+60,env.now+60);assert(claimed.watermark==env.now+60)
 assert(not pcall(Store.claim,fs,active.generation,env.now+60,env.now+61))
 Store.change(fs,false,nil,env);assert(not Store.decode(files['automatic.json']).enabled)
end)
test('startup/downtime floor persists across later backward restart',function()
 local active=Store.change(fs,true,draft.revision,env)
 local high=Store.advance(fs,active.generation,env.now+3600)
 assert(high.watermark==env.now+3600)
 assert(Store.advance(fs,active.generation,env.now+60).watermark==high.watermark)
 local e=A.new(env.now+100,0,high.watermark)
 assert(not e.step(env.now+101,1,{{utc=env.now+101}},false))
end)
test('all publication failures prohibit playback; old or new complete state',function()
 local baseline=files['automatic.json']
 for i=1,4 do
  files['automatic.json']=baseline;files['automatic-next.json']=nil;steps=0;fail_at=i
  assert(not pcall(Store.change,fs,true,draft.revision,env));fail_at=nil
  local restored=Store.decode(files['automatic.json']);assert(type(restored.enabled)=='boolean')
 end
end)
test('stop retains applied plan, resume ignores newer draft and preserves watermark',function()
 files['automatic.json']=nil;fail_at=nil
 local applied=Store.change(fs,true,draft.revision,env)
 Store.claim(fs,applied.generation,env.now+60,env.now+60)
 local stopped=Store.change(fs,false,nil,env)
 assert(not stopped.enabled and stopped.revision==draft.revision and stopped.plan.schedules[1].name=='School')
 local changed=C.decode(C.encode(d));changed.schedules[1].name='New draft'
 local saved=assert(S.save(fs,C.encode(changed),draft.revision));assert(saved.ok)
 local snapshot=files['automatic.json'];local checked=0
 assert(not pcall(Store.resume,fs,saved.revision,stopped.generation,env,function()error('wrong plan admitted')end))
 assert(not pcall(Store.resume,fs,stopped.revision,stopped.generation-1,env,function()return true end))
 assert(not pcall(Store.resume,fs,stopped.revision,stopped.generation,env,function()return false end))
 assert(files['automatic.json']==snapshot)
 local resumed=Store.resume(fs,stopped.revision,stopped.generation,env,function(plan)checked=checked+1;assert(plan.schedules[1].name=='School');return true end)
 assert(resumed.enabled and resumed.revision==draft.revision and resumed.watermark==env.now+60 and checked==1)
 assert(S.load(fs).revision==saved.revision)
 assert(not pcall(Store.resume,fs,stopped.revision,stopped.generation,env,function()return true end))
end)
test('resume publication faults retain a complete old or new snapshot',function()
 local stopped=Store.change(fs,false,nil,env);local baseline=files['automatic.json']
 for i=1,4 do
  files['automatic.json']=baseline;files['automatic-next.json']=nil;steps=0;fail_at=i
  assert(not pcall(Store.resume,fs,stopped.revision,stopped.generation,env,function()return true end));fail_at=nil
  local recovered=Store.decode(files['automatic.json']);assert(recovered.revision==stopped.revision)
  assert(recovered.generation==stopped.generation or recovered.generation==stopped.generation+1)
 end
end)
test('legacy stopped state and failed resume cannot invent a plan',function()
 files['automatic.json']=nil
 local stopped=Store.change(fs,false,nil,env);assert(not stopped.plan)
 assert(not pcall(Store.resume,fs,draft.revision,stopped.generation,env,function()return true end))
end)
test('corruption refuses recovery/activation',function()files['automatic.json']='broken';assert(not pcall(Store.change,fs,true,draft.revision,env))end)
local method,length,security,status='POST','2000',0,nil
package.loaded['luci.http']={getenv=function(k)if k=='REQUEST_METHOD'then return method elseif k=='CONTENT_LENGTH'then return length else return 'application/x-www-form-urlencoded'end end,status=function(s)status=s end,formvalue=function()error('unexpected parse')end}
package.loaded['luci.dispatcher']={test_post_security=function()security=security+1;return false end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
test('HTTP method, bounds, CSRF before storage',function()local f=luci.controller.schoolbell_test.automatic;f();assert(status==413 and security==0);length='100';f();assert(security==1);method='PUT';f();assert(status==405)end)
print('automatic: '..count..' groups PASS')
