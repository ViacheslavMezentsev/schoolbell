package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local M=require('schoolbell.system_actions');local Mail=require('schoolbell.clock_mailbox')
local now,calls=100,0;local target
local handle=M.new({now=function()return now end,run=function(t)calls=calls+1;target=t;return {ok=true}end})
local function q(action,extra)local v={id=string.rep('a',32),owner=string.rep('b',64),action=action};for k,x in pairs(extra or {})do v[k]=x end;return v end
assert(not handle(q('system_reset',{challenge=string.rep('a',32),ack='true'})).ok and calls==0)
for _,name in ipairs({'reset','reboot'})do
 local prepare=q('system_prepare',{target=name});assert(Mail.valid(prepare));assert(handle(prepare).ok and calls==0)
 local confirm=q('system_'..name,{challenge=prepare.id,ack='true'});assert(Mail.valid(confirm))
 local wrong=q('system_'..name,{challenge=prepare.id,ack='true'});wrong.owner=string.rep('c',64)
 assert(not handle(wrong).ok);assert(not handle(q(name=='reset'and 'system_reboot'or 'system_reset',{challenge=prepare.id,ack='true'})).ok)
 assert(handle(confirm).ok and target==name);assert(not handle(confirm).ok);calls=0
 handle(prepare);now=now+31;assert(not handle(confirm).ok and calls==0)
 local fresh=M.new({now=function()return now end,run=function()error('must not run')end});assert(not fresh(confirm).ok)
end
assert(not Mail.valid(q('system_prepare',{target='shell'})))
assert(not Mail.valid(q('system_reset',{challenge=string.rep('a',32),ack='false'})))
assert(not Mail.valid(q('system_reset',{challenge=string.rep('a',32),ack='true',target='reset'})))
assert(not Mail.valid(q('prepare',{target='reset'})))
print('PASS system confirmation: owner/target/expiry/restart/single use and strict mailbox admission; no device actions')
