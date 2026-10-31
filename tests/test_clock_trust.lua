local C=require('schoolbell.clock_reference');local Store=require('schoolbell.clock_reference_store');local Model=require('schoolbell.clock_trust')
local base=1790000000000;local tests=0
local function test(name,fn)fn();tests=tests+1;print('PASS clock trust '..name)end
local function record(t)return {format='schoolbell-clock/1',source='manual',confirmed_utc_ms=t or base,checkpoint_utc_ms=t or base}end
local function fs_fixture(initial)
 local x={files={},writes=0,operations={},locked=false,fail=nil,return_false=false}
 if initial then x.files[Store.name]=initial end
 function x.open()
  assert(not x.locked,'busy');x.locked=true
  local function op(name)
   x.operations[#x.operations+1]=name
   if x.fail==name then if x.return_false then return false end;error('injected '..name)end
   return true
  end
  return {read=function(p,max)assert(op('read'));local v=x.files[p];assert(not v or #v<=max);return v end,
   stat=function(p)return x.files[p] and {}end,
   unlink=function(p)if not op('unlink')then return false end;x.files[p]=nil end,
   write=function(p,v)if not op('write')then return false end;x.writes=x.writes+1;x.files[p]=v end,
   sync=function(p)return op(p=='' and 'directory_sync' or 'file_sync')end,
   rename=function(a,b)if not op('rename')then return false end;x.files[b]=x.files[a];x.files[a]=nil end,
   close=function()x.locked=false;return op('close')end}
 end
 x.store=Store.new(x.open);return x
end
local function rig(initial,options)
 local x=fs_fixture(initial);x.utc=base;x.mono=0;x.width=0;x.context='boot-a';x.clock_calls=0
 x.io={store=x.store,valid_utc=function(v)return v>=base-86400000 and v<base+31536000000 end,
  clock=function()x.clock_calls=x.clock_calls+1;if x.clock_error then error('clock failed')end;return {utc_ms=x.utc,before_ms=x.mono,after_ms=x.mono+x.width,context=x.context}end}
 x.model=Model.new(x.io,options)
 function x.advance(ms,shift)x.mono=x.mono+ms;x.utc=x.utc+ms+(shift or 0)end
 function x.confirm(ack)local q=assert(x.model.request_confirmation());local r=x.model.confirm(q.token,ack);assert(r.ok,r.code)end
 function x.run(ms)while ms>0 do local step=math.min(ms,1000);x.advance(step);x.model.observe();ms=ms-step end end
 return x
end
test('canonical vector / UTC-ms / max integer',function()
 local r=record();r.checkpoint_utc_ms=1790003600000
 local raw,hash=C.encode(r);local decoded=C.decode(raw);assert(decoded.checkpoint_utc_ms==r.checkpoint_utc_ms)
 assert(hash=='86564f73b3bfb2ae97c8237e7d239760a71318a26d5dc3c07f1dc59e30555be4');assert(C.data(r)=='{"checkpoint_utc_ms":1790003600000,"confirmed_utc_ms":1790000000000,"format":"schoolbell-clock/1","source":"manual"}')
 r=record(C.max_integer);assert(C.decode(C.encode(r)).confirmed_utc_ms==C.max_integer)
 assert(not pcall(C.encode,record(C.max_integer+1)))
end)
test('strict schema / types / syntax / checksum / 1024 boundary',function()
 local raw=C.encode(record());assert(C.decode(raw..string.rep(' ',1024-#raw)))
 for _,s in ipairs({raw..string.rep(' ',1025-#raw),raw:gsub('"manual"','"ntp"'),raw:gsub('schoolbell%-clock/1','schoolbell-clock/2'),raw:gsub('1790000000000','1790000000000.0'),raw:gsub('1790000000000','1.790000000000e12'),raw:gsub('1790000000000','-1'),raw:gsub('"source":"manual"','"source":"manual","source":"manual"'),raw:gsub('"source":"manual"','"source":"manual","extra":true'),raw:gsub('"checksum":".','"checksum":"z'),raw:sub(1,-2),'[]'})do assert(not pcall(C.decode,s),s)end
 local r=record();r.checkpoint_utc_ms=base-1;assert(not pcall(C.encode,r))
 for _,v in ipairs({false,'1',-1,0.5,math.huge})do r=record();r.confirmed_utc_ms=v;assert(not pcall(C.encode,r))end
end)
test('atomic ordering / orphan ignored / CAS',function()
 local x=fs_fixture();x.files[Store.temporary]='orphan';assert(x.store.load().revision=='empty')
 x.operations={};local r=x.store.save(record(),'empty');assert(r.ok and x.writes==1)
 assert(table.concat(x.operations,',')=='read,unlink,write,file_sync,rename,directory_sync,read,close')
 assert(x.store.load().revision==r.revision and not x.files[Store.temporary])
 assert(x.store.save(record(base+1),'empty').code=='conflict' and x.writes==1)
end)
test('all storage fault stages, exceptions and false returns',function()
 local old,revision=C.encode(record())
 for _,point in ipairs({'read','write','file_sync','rename','directory_sync','close'})do for _,mode in ipairs({false,true})do
  local x=fs_fixture(old);x.fail=point;x.return_false=mode
  assert(not x.store.save(record(base+1000),revision).ok and not x.locked)
  local current=C.decode(x.files[Store.name]);assert(current.checkpoint_utc_ms==base or current.checkpoint_utc_ms==base+1000)
  x.fail=nil;local recovered=rig(x.files[Store.name]);assert(recovered.model.status().state=='unconfirmed' and not recovered.model.admit())
 end end
 local x=fs_fixture('broken');assert(not x.store.load().ok);assert(not x.store.save(record(),'empty').ok and x.writes==0)
end)
test('empty / corrupt / unsupported reference never trusted',function()
 for _,raw in ipairs({'broken',C.encode(record()):gsub('schoolbell%-clock/1','schoolbell-clock/9')})do local x=rig(raw);assert(not x.model.admit());assert(x.model.request_confirmation()==nil and x.writes==0)end
 local x=rig();assert(x.model.observe().state=='unconfirmed' and not x.model.enable().ok and not x.model.admit())
end)
test('rollback strict default and custom thresholds',function()
 for _,threshold in ipairs({1,5,60})do for _,offset in ipairs({-1,0,1})do
  local x=rig(C.encode(record(base+threshold*1000+offset)),{rollback_seconds=threshold});local s=x.model.observe()
  assert(s.state==(offset>0 and 'rollback_detected' or 'unconfirmed'));assert(not x.model.enable().ok)
 end end
end)
test('manual confirmation, separate enable, single-use instance token',function()
 local x=rig();local q=x.model.request_confirmation();assert(x.model.confirm(q.token).ok)
 assert(x.model.status().state=='confirmed' and not x.model.admit());assert(x.model.enable().ok and x.model.admit())
 assert(not x.model.confirm(q.token).ok);x.model.disable();assert(not x.model.admit())
 local y=rig(x.files[Store.name]);assert(not y.model.confirm(q.token).ok and y.model.status().state~='confirmed')
end)
test('future reference explicit acknowledgement',function()
 local x=rig(C.encode(record(base+10000)));local q=x.model.request_confirmation();assert(q.requires_rollback_ack)
 assert(x.model.confirm(q.token,false).code=='rollback_ack_required' and x.writes==0)
 x.confirm(true);assert(x.model.status().checkpoint_utc_ms==base and not x.model.admit())
end)
test('request expiry 14999 / 15000 / 15001 with continuous observation',function()
 for _,age in ipairs({14999,15000,15001})do local x=rig();local q=x.model.request_confirmation();x.run(age);assert(x.model.confirm(q.token).ok==(age<15000))end
end)
test('boot/context and gaps invalidate pending confirmation',function()
 for _,kind in ipairs({'context','gap','step','read'})do
  local x=rig();local q=x.model.request_confirmation()
  if kind=='context'then x.context='boot-b' elseif kind=='gap'then x.advance(3001) elseif kind=='step'then x.advance(1000,5001)else x.clock_error=true end
  assert(not x.model.confirm(q.token).ok and x.writes==0)
 end
end)
test('signed step boundaries / conservative uncertain bracket',function()
 for _,sign in ipairs({-1,1})do for _,size in ipairs({4999,5000,5001})do
  local x=rig();x.confirm();x.model.enable();x.advance(1000,sign*size)
  assert(x.model.admit()==(size<=5000));if size>5000 then assert(x.model.status().state=='review_required')end
 end end
 local x=rig();x.confirm();x.model.enable();x.advance(1000,5050);x.width=100
 assert(not x.model.admit() and x.model.status().reason=='clock_step_uncertain')
end)
test('observation gap 3000 / 3001, pair 100 / 101, backwards MONO',function()
 for _,gap in ipairs({3000,3001})do local x=rig();x.confirm();x.model.enable();x.advance(gap);assert(x.model.admit()==(gap==3000))end
 for _,width in ipairs({100,101})do local x=rig();x.width=width;assert(x.model.observe().state==(width==100 and 'unconfirmed' or 'review_required'))end
 local x=rig();x.mono=1000;x.confirm();x.model.enable();x.mono=999;assert(not x.model.admit())
end)
test('invalid clock / unsupported UTC / exceptions fail closed',function()
 local x=rig();x.confirm();x.model.enable();x.utc=0;assert(not x.model.admit())
 x=rig();x.confirm();x.model.enable();x.clock_error=true;assert(not x.model.admit())
 x=rig();x.confirm();x.model.enable();x.mono=-1;assert(not x.model.admit())
end)
test('hourly checkpoint, no fresh confirmation, disabled auto',function()
 local x=rig();x.confirm();local first=x.model.status().confirmed_utc_ms
 x.run(3599000);assert(x.writes==1);x.run(1000);assert(x.writes==2)
 local s=x.model.status();assert(s.confirmed_utc_ms==first and s.checkpoint_utc_ms==base+3600000 and s.source=='manual' and not s.enabled)
 x.run(1000);assert(x.writes==2)
end)
test('no catch-up writes after gap or trust loss',function()
 local x=rig();x.confirm();x.advance(7200000);x.model.observe();assert(x.writes==1 and x.model.status().state=='review_required');x.run(5000);assert(x.writes==1)
end)
test('all commit errors block confirmation and periodic checkpoint',function()
 for _,point in ipairs({'write','file_sync','rename','directory_sync','close'})do
  local x=rig();local q=x.model.request_confirmation();x.fail=point;assert(not x.model.confirm(q.token).ok and not x.model.admit())
  x=rig();x.confirm();x.model.enable();x.run(3599000);x.fail=point;x.advance(1000);assert(not x.model.admit() and x.model.status().state=='review_required')
 end
end)
test('slow commit invalidates permit without false successful confirmation',function()
 local x=rig();local save=x.store.save;x.store.save=function(...)local out=save(...);x.advance(3001);return out end
 local q=x.model.request_confirmation();assert(not x.model.confirm(q.token).ok and not x.model.admit())
end)
test('threshold validation / changes never clear a block',function()
 local x=rig();for _,n in ipairs({0,61,1.5,'5',false})do assert(not x.model.configure({rollback_seconds=n,step_seconds=5}).ok)end
 x.confirm();x.model.enable();x.advance(1000,5001);assert(not x.model.admit());assert(x.model.configure({rollback_seconds=60,step_seconds=60}).ok and not x.model.admit())
end)
test('fresh final admission and observation through long player wait',function()
 local x=rig();x.confirm();x.model.enable();local calls=x.clock_calls;assert(x.model.admit() and x.clock_calls>calls)
 x.run(62000);assert(x.model.admit() and x.writes==1)
 x.advance(1000,-5001);assert(not x.model.admit());x.confirm(true);assert(not x.model.admit()) -- explicit enable still required
end)
test('bounded transition events and no poll logging or borrowed state',function()
 local x=rig();x.confirm();x.model.drain_events();x.run(10000);assert(#x.model.drain_events()==0)
 local s=x.model.status();s.enabled=true;s.state='confirmed';assert(not x.model.admit())
 for i=1,40 do x.context='epoch-'..i;x.model.observe();x.confirm()end
 local events,dropped=x.model.drain_events();assert(#events<=16 and dropped>0);events[1].reason='mutated';assert(#x.model.drain_events()==0)
end)
test('checkpoint period starts after successful persistence',function()
 local x=rig();local save=x.store.save
 x.store.save=function(...)local out=save(...);x.advance(500);return out end
 x.confirm();x.run(3599500);assert(x.writes==1)
 x.run(500);assert(x.writes==2)
 x.run(3599500);assert(x.writes==2);x.run(500);assert(x.writes==3)
end)
test('overlapping rounded pairs are not reversed time',function()
 local x=rig();x.width=5;x.confirm();assert(x.model.enable().ok)
 for i=1,20 do x.advance(1);assert(x.model.admit())end
 x.mono=x.mono-1;assert(not x.model.admit())
end)
print('clock trust: '..tests..' groups PASS (isolated, no system clock/player/storage)')
