local Gate=require('schoolbell.clock_gate');local C=require('schoolbell.clock_reference')
local total=0
local function test(name,fn)fn();total=total+1;print('PASS clock gate '..name)end
local function rig(options)
 local x={utc=1790000000000,mono=0,reads=0,writes=0,opens=0,revision='empty',context='boot-a'}
 x.io={valid_utc=function(v)return v>=0 and v<2145916800000 end,
 clock=function()x.reads=x.reads+1;if x.read_fail then error('clock read')end;return {utc_ms=x.utc,before_ms=x.mono,after_ms=x.mono,context=x.context}end,
 store={load=function()return {ok=true,data=x.data,revision=x.revision}end,save=function(v)if x.write_fail then return {ok=false}end;x.writes=x.writes+1;x.data=v;local _,hash=C.encode(v);x.revision=hash;return {ok=true,revision=hash}end}}
 x.open=function()x.opens=x.opens+1;if x.open_fail then error('unavailable')end;return x.io end
 x.gate=Gate.new(x.open,options)
 function x.advance(ms,jump)x.mono=x.mono+ms;x.utc=x.utc+ms+(jump or 0)end
 function x.confirm()local q=assert(x.gate.request_confirmation());assert(x.gate.confirm(q.token,false).ok)end
 return x
end
test('default enabled; confirmation and enable are separate',function()
 local x=rig();assert(x.gate.status().enforced and not x.gate.admit());assert(not x.gate.enable().ok)
 x.confirm();assert(not x.gate.admit());assert(x.gate.enable().ok and x.gate.admit());assert(x.writes==1)
 x.gate.disable();assert(not x.gate.admit())
end)
test('clock set invalidation revokes trust and stale tokens without reference writes',function()
 local x=rig();x.confirm();x.gate.enable();local token=x.gate.request_confirmation();local writes=x.writes
 x.gate.invalidate();assert(not x.gate.admit() and not x.gate.enable().ok and x.writes==writes)
 assert(not x.gate.confirm(token.token,false).ok)
 local b=rig({enforced=false});b.gate.enable();b.gate.invalidate();assert(not b.gate.admit() and b.opens==0)
end)
test('explicit bypass opens no clock/reference and never enables by itself',function()
 local x=rig({enforced=false});assert(x.opens==0 and x.reads==0);assert(x.gate.status().state=='unchecked' and not x.gate.status().accuracy_known)
 assert(not x.gate.admit());assert(x.gate.enable().ok and x.gate.admit());x.gate.observe();assert(x.reads==0 and x.writes==0)
 assert(not x.gate.configure('false').ok);assert(not x.gate.status().enforced)
end)
test('policy changes revoke activation and old confirmation tokens',function()
 local x=rig();local q=assert(x.gate.request_confirmation());x.gate.configure(false);assert(not x.gate.admit());assert(x.gate.enable().ok)
 x.gate.configure(true);assert(not x.gate.admit());assert(not x.gate.confirm(q.token,false).ok);assert(not x.gate.enable().ok)
 x.confirm();assert(x.gate.enable().ok);x.gate.configure(false);assert(not x.gate.admit());assert(x.gate.enable().ok and x.gate.admit())
end)
test('restart/reference and context change do not restore trust',function()
 local x=rig();x.confirm();x.gate.enable();x.gate=Gate.new(x.open);assert(not x.gate.enable().ok)
 x.confirm();x.gate.enable();x.context='boot-b';assert(not x.gate.admit());assert(x.gate.status().state=='unconfirmed')
end)
test('fresh admission catches preparation delay and UTC step',function()
 for _,kind in ipairs({'gap','step','read'})do
  local x=rig();x.confirm();x.gate.enable();assert(x.gate.status().automatic_permitted)
  if kind=='gap'then x.advance(3001)elseif kind=='step'then x.advance(1000,6000)else x.read_fail=true end
  assert(not x.gate.admit());assert(not x.gate.status().automatic_permitted)
 end
end)
test('hourly persistence failure blocks; observation does not write every second',function()
 local x=rig();x.confirm();x.gate.enable()
 for i=1,3599 do x.advance(1000);x.gate.observe()end;assert(x.writes==1)
 x.write_fail=true;x.advance(1000);x.gate.observe();assert(not x.gate.admit())
end)
test('computation observations never checkpoint and still reject steps',function()
 local x=rig();x.confirm();x.gate.enable()
 for i=1,3601 do x.advance(1000);x.gate.observe(false)end
 assert(x.writes==1 and x.gate.admit()) -- admit performs the regular checkpoint
 assert(x.writes==2)
 x.advance(500,6000);x.gate.observe(false)
 assert(not x.gate.status().automatic_permitted and x.gate.status().reason=='clock_step')
end)
test('missing dependency blocks by default; explicit bypass remains separate',function()
 local g=Gate.new(function()error('native absent')end);assert(g.status().reason=='clock_unavailable');assert(not g.enable().ok and not g.admit())
 assert(g.configure(false).ok);assert(not g.admit());assert(g.enable().ok and g.admit())
end)
test('local policy defaults on; only explicit boolean false bypasses native port',function()
 local oldopen=io.open;local oldfs=package.loaded['nixio.fs'];local oldnative=package.loaded['schoolbell.clock_linux'];local oldpreload=package.preload['schoolbell.clock_linux']
 local raw,exists,native_calls=nil,false,0;local pending=false
 package.loaded['nixio.fs']={lstat=function(path)if path:match('clock%-policy.pending$')then return pending and {type='reg'} or nil end;return exists and {type='reg',size=raw and #raw or 1} or nil end}
 package.loaded['schoolbell.clock_linux']=nil
 package.preload['schoolbell.clock_linux']=function()native_calls=native_calls+1;error('not installed')end
 io.open=function(path)assert(path=='/etc/schoolbell-editor/clock-policy.json');if raw==nil then return nil end;return {read=function(_,n)return raw:sub(1,n)end,close=function()return true end}end
 local g=Gate.system();assert(g.status().enforced and not g.enable().ok and native_calls==1)
 raw='{"enforced":false}';exists=true;g=Gate.system();assert(not g.status().enforced and not g.admit());assert(g.enable().ok and g.admit());assert(native_calls==1)
 for _,bad in ipairs({'{"enforced":"false"}','{"enforced":false,"extra":1}','{"enforced":false,"enforced":true}',string.rep(' ',257),'null'})do raw=bad;g=Gate.system();assert(g.status().enforced and not g.enable().ok)end
 raw='{"enforced":false}';pending=true;g=Gate.system();assert(g.status().enforced and not g.enable().ok);pending=false
 raw=nil;g=Gate.system();assert(g.status().enforced and not g.admit())
 io.open=oldopen;package.loaded['nixio.fs']=oldfs;package.loaded['schoolbell.clock_linux']=oldnative;package.preload['schoolbell.clock_linux']=oldpreload
end)
print('clock gate: '..total..' groups PASS')
