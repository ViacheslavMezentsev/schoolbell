local Commands=require('schoolbell.clock_commands');local Mail=require('schoolbell.clock_mailbox');local Gate=require('schoolbell.clock_gate')
local writes,stops,enabled,now=0,0,0,100
local stamp=1790000000000;local mono=0;local data
local io={valid_utc=function()return true end,clock=function()return {utc_ms=stamp,before_ms=mono,after_ms=mono,context='epoch'}end,store={load=function()return {ok=true,revision='empty'}end,save=function(v)data=v;local _,hash=require('schoolbell.clock_reference').encode(v);return {ok=true,revision=hash}end}}
local gate=Gate.new(function()return io end)
local fail=false
local ports={zone=function()return 'UTC' end,stop=function()stops=stops+1;return true end,policy=function()writes=writes+1;return not fail end,enable=function()enabled=enabled+1;return {ok=true}end}
local handle=Commands.new(gate,ports)
local q={id=string.rep('a',32),owner=string.rep('b',64),action='prepare'}
assert(not handle({action='enable',revision='x'}).ok and enabled==0)
local v=handle(q);assert(v.ok and v.utc==1790000000 and not gate.admit())
assert(not handle({action='confirm',owner='other',challenge=q.id,ack='false'}).ok)
assert(handle({action='confirm',owner=q.owner,challenge=q.id,ack='false'}).ok and stops==1)
assert(not gate.admit());assert(handle({action='enable',revision='x'}).ok and enabled==1)
assert(not gate.admit())
assert(not handle({action='confirm',owner=q.owner,challenge=q.id}).ok)
v=handle(q);mono=mono+15000;stamp=stamp+15000
assert(not handle({action='confirm',owner=q.owner,challenge=q.id,ack='false'}).ok)
assert(handle({action='policy',enforced='false'}).ok and not gate.status().enforced and not gate.admit())
fail=true;assert(not handle({action='policy',enforced='false'}).ok and gate.status().enforced)
local fresh=Commands.new(gate,ports);assert(not fresh({action='confirm',owner=q.owner,challenge=q.id}).ok)
local files={};local fault=false
local fs={read=function(k)return files[k]end,stat=function(k)return files[k]~=nil end,write=function(k,v)if fault then error('write')end;files[k]=v end,rename=function(a,b)files[b]=files[a];files[a]=nil end,unlink=function(k)files[k]=nil end,close=function()end}
local m=Mail.new(function()return fs end,function()return now end);local calls=0
local function exec()calls=calls+1;return {ok=true}end
assert(m.submit(q).ok);assert(m.submit(q).ok)
assert(not m.submit({id=q.id,owner=string.rep('c',64),action='prepare'}).ok)
assert(m.process(exec).ok and calls==1);assert(m.poll(q.id,q.owner).ok)
assert(m.poll(q.id,'other').pending);assert(m.submit(q).ok);m.process(exec);assert(calls==1)
q.id=string.rep('d',32);assert(m.submit(q).ok);now=116;assert(m.process(exec).code=='expired' and calls==1)
q.id=string.rep('e',32);assert(m.submit(q).ok);fault=true;assert(not m.process(exec).ok and calls==1);fault=false
assert(m.process(exec).ok and calls==2)
q.id=string.rep('f',32);assert(m.submit(q).ok)
assert(m.process(function()calls=calls+1;error('interrupted')end).code=='operation_failed');m.submit(q);m.process(exec);assert(calls==3)
assert(not m.submit({id='x',owner=q.owner,action='policy',enforced='false'}).ok)
assert(not m.submit({id=q.id,owner=q.owner,action='policy',enforced='false',extra=true}).ok)
print('PASS clock commands: confirmation ownership/expiry/restart, explicit bypass, fail-closed policy, activation, mailbox dedupe/expiry/faults')

local locked=false;local corrupt=false
local channel=Mail.new(function()if locked then error('busy')end;if corrupt then error('permission denied')end;return fs end,function()return now end)
q.id=string.rep('1',32);assert(channel.submit(q).ok)
channel.process(function()
 locked=true
 local p=channel.poll(q.id,q.owner);assert(p.ok and p.pending and p.waiting=='writer')
 local rejected=channel.submit({id=string.rep('2',32),owner=q.owner,action='prepare'})
 assert(not rejected.ok and rejected.code=='busy' and rejected.accepted==false)
 locked=false;return {ok=true,completed=true}
end)
assert(channel.poll(q.id,q.owner).completed)
corrupt=true;assert(channel.poll(q.id,q.owner).code=='mailbox_storage');corrupt=false
files['result.json']='not json';assert(channel.poll(q.id,q.owner).code=='mailbox_storage')
print('PASS clock mailbox: read during worker commit stays pending, POST is not accepted twice, corruption is not busy')

local qresume={id=string.rep('9',32),owner=string.rep('8',64),action='resume',revision=string.rep('7',64),generation='3'}
assert(Mail.valid(qresume));qresume.generation='03';assert(not Mail.valid(qresume));qresume.generation='2147483648';assert(not Mail.valid(qresume));qresume.generation='3'
qresume.action='enable';assert(not Mail.valid(qresume));qresume.action='resume'
local disabled=0;local resumed=0
local fake={enable=function()return {ok=true}end,admit=function()return true end,disable=function()disabled=disabled+1 end}
local dispatch=Commands.new(fake,{resume=function(rev,gen)assert(rev==qresume.revision and gen==3);resumed=resumed+1;return {ok=true,generation=4}end})
assert(dispatch(qresume).generation==4 and resumed==1 and disabled==1)
dispatch=Commands.new(fake,{resume=function()error('storage fault')end});assert(dispatch(qresume).code=='operation_failed' and disabled==2)
print('PASS resume mailbox bounds, separate port and clock-gate cleanup on failure')
