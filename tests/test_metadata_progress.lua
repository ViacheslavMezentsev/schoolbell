local C=require('schoolbell.media_codec')
local Gate=require('schoolbell.clock_gate')
local mono,utc=0,1790000000000
local gate=Gate.new(function()return {valid_utc=function()return true end,clock=function()return {before_ms=mono,after_ms=mono,utc_ms=utc,context='boot'}end,store={load=function()return {ok=true,revision='empty'}end,save=function(v)local _,hash=require('schoolbell.clock_reference').encode(v);return {ok=true,revision=hash}end}}end)
local q=assert(gate.request_confirmation());assert(gate.confirm(q.token,false).ok);assert(gate.enable().ok)
local calls=0
C.set_observer(function()calls=calls+1;mono=mono+100;utc=utc+100;gate.observe(false);C.sha('nested observation')end)
local value=string.rep('a',16384)
assert(C.sha(value)=='f3336bea752b5a28743033dd2c844a4a63fba08871aaee2586a2bf2d69be83a2')
assert(calls>40 and gate.admit()) -- Work exceeds 3 seconds, observations stay continuous.
local before=calls;assert(C.sha(value)=='f3336bea752b5a28743033dd2c844a4a63fba08871aaee2586a2bf2d69be83a2');assert(calls==before+1) -- exact-byte cache
assert(C.sha(value:sub(2))~='f3336bea752b5a28743033dd2c844a4a63fba08871aaee2586a2bf2d69be83a2') -- changed bytes cannot reuse result
mono=mono+3001;utc=utc+3001;assert(not gate.admit());assert(gate.status().reason=='observation_gap')
C.set_observer(function()error('observer failed')end);assert(not pcall(C.sha,'abc'))
C.set_observer(nil);assert(C.sha('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
for i=1,6 do C.sha(tostring(i))end
assert(C.sha('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
print('PASS metadata: known SHA, exact cache/eviction, bounded observation, reentrancy, gap still blocks, observer error propagates')
