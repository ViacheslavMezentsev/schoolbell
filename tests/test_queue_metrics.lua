local M=require('schoolbell.queue_metrics');local Mail=require('schoolbell.clock_mailbox');local C=require('schoolbell.media_codec')
local s=M.apply(nil,'queued',1,nil,'worker');assert(s.depth==1)
s=M.apply(s,'start',1.25,0.25);assert(s.depth==0 and s.running==1 and s.bins[1].wait_max==250)
s=M.apply(s,'finish',11,false);assert(s.running==0 and #s.bins==3 and s.bins[2].running==1 and s.bins[3].processed==1 and s.bins[3].failed==1)
s=M.apply(s,'tick',80);assert(#s.bins==12 and s.bins[1].key==5)
s=M.apply(s,'reset',81,nil,'new');assert(s.epoch=='new' and s.depth==0 and s.running==0 and #s.bins==1)
local t=100.25;local files={};local fs={read=function(k)return files[k]end,stat=function(k)return files[k]~=nil end,write=function(k,v)files[k]=v end,rename=function(a,b)files[b]=files[a];files[a]=nil end,unlink=function(k)files[k]=nil end,close=function()end}
local obs=M.observer(function()return t end,false,'cgi');local m=Mail.new(function()return fs end,function()return t end,obs)
local q={id=string.rep('a',32),owner=string.rep('b',64),action='prepare'}
assert(m.submit(q).ok);local raw=files['metrics.json'];assert(m.submit(q).ok and files['metrics.json']==raw)
local worker=Mail.new(function()return fs end,function()return t end,M.observer(function()return t end,true,'worker'))
t=100.75;local calls=0
assert(worker.process(function()calls=calls+1;local v=C.decode(files['metrics.json']);assert(v.depth==0 and v.running==1);assert(v.bins[1].wait_max==500);t=106;return {ok=true}end).ok)
local v=C.decode(files['metrics.json']);assert(v.running==0 and v.bins[#v.bins].processed==1)
worker.process(function()calls=calls+1 end);assert(calls==1)
q.id=string.rep('c',32);assert(m.submit(q).ok);t=t+16;assert(worker.process(function()error('must not execute')end).code=='expired')
v=C.decode(files['metrics.json']);assert(v.bins[#v.bins].expired==1)
local broken=Mail.new(function()return fs end,function()return t end,function()error('telemetry failed')end)
q.id=string.rep('d',32);assert(broken.submit(q).ok);assert(broken.process(function()return {ok=true}end).ok);assert(files['metrics.json']==nil)
local restart=M.observer(function()return t end,true,'restart');restart(fs,'tick');v=C.decode(files['metrics.json']);assert(v.epoch=='restart' and v.running==0)
for i=1,200 do t=t+5;restart(fs,'tick');assert(#files['metrics.json']<=4096 and #C.decode(files['metrics.json']).bins<=12)end
print('PASS queue metrics: actual mailbox depth/wait/completions, dedupe, expiry, reset, bounded history, observer failure isolation')

local CPU=require('schoolbell.system_metrics');local c=CPU.parse('cpu 100 20 30 400 50 6 7 8 999 999');assert(c.total=='621' and c.idle=='450');assert(not CPU.parse('intr 100').available)

q.id=string.rep('e',32);assert(m.submit(q).ok);t=t+21;q.id=string.rep('f',32);assert(m.submit(q).ok);v=C.decode(files['metrics.json']);assert(v.depth==1 and v.bins[#v.bins].expired==1)

assert(CPU.uptime('886200.99 100.00\n')==886200)
assert(CPU.uptime('0.00 0.00\n')==0)
assert(CPU.uptime('-1.0 0\n')==nil and CPU.uptime('bad')==nil and CPU.uptime(nil)==nil)
local open=io.open
io.open=function(path)
 if path=='/proc/uptime' then return nil end
 return {read=function()return path=='/proc/stat' and 'cpu 1 2 3 4 5 6 7 8' or 'boot' end,close=function()end}
end
local sampled=CPU.read();io.open=open;assert(sampled.available and sampled.uptime_seconds==nil)
print('PASS uptime parser and absent uptime does not hide CPU counters')

local oldfs=package.loaded['nixio.fs'];io.open=function(path)return {read=function()return path=='/proc/stat' and 'cpu 1 2 3 4 5 6 7 8' or path=='/proc/uptime' and '5.0 1.0' or 'boot' end,close=function()end}end
package.loaded['nixio.fs']={statvfs=function(path)assert(path=='/overlay');return {blocks=1024,bavail=256,frsize=4096}end}
local flash=CPU.read();assert(flash.available and flash.storage.total_kib==4096 and flash.storage.free_kib==1024)
for _,space in ipairs({{}, {blocks=1024,bavail=-1,frsize=4096}, {blocks=0,bavail=0,frsize=4096}})do package.loaded['nixio.fs'].statvfs=function()return space end;local v=CPU.read();assert(v.available and v.storage==nil)end
package.loaded['nixio.fs'].statvfs=function()error('unavailable')end;assert(CPU.read().available)
io.open=open;package.loaded['nixio.fs']=oldfs
print('PASS Flash statvfs capacity/free and unavailable disk never hides CPU')
