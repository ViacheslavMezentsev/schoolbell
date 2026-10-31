local M=require('schoolbell.controls');local C=require('schoolbell.media_codec')
local files={};local writes=0
local fs={read=function(p)return files[p]end,stat=function(p)return files[p] and {}end,write=function(p,v)files[p]=v;writes=writes+1 end,sync=function()end,rename=function(a,b)files[b]=files[a];files[a]=nil end,unlink=function(p)files[p]=nil end,close=function()end}
local original=package.loaded['schoolbell.media_fs'];package.loaded['schoolbell.media_fs']={new=function()return fs end}
assert(M.request().muted==false and writes==0)
local on=M.request(true);assert(on.ok and on.muted and on.generation==1)
assert(M.request(true).generation==1 and writes==1)
local off=M.request(false);assert(off.ok and not off.muted and off.generation==2)
assert(M.decode(files['sound-control.json']).generation==2)
local quiet=M.request(nil,nil,-12);assert(quiet.ok and quiet.volume_db==-12 and quiet.generation==2 and not quiet.muted)
local muted=M.request(true);assert(muted.volume_db==-12 and muted.generation==3)
local low=M.request(nil,nil,-24);assert(low.muted and low.generation==3 and low.volume_db==-24)
assert(not M.request(nil,nil,1).ok);assert(not M.request(nil,nil,-61).ok);assert(not M.request(nil,nil,-1.5).ok)
assert(M.decode('{"muted":false,"generation":0}').volume_db==0)
assert(not pcall(M.decode,'{"muted":false,"generation":0,"volume_db":"-12"}'))
files['sound-control.json']='broken';assert(not M.request(false).ok)
package.loaded['schoolbell.media_fs']=original
local savedRead=M.read;M.read=function()return {muted=true,generation=7}end
package.loaded['schoolbell.media_fs']={new=function()error('writer lock busy')end}
assert(M.snapshot().muted and M.snapshot().generation==7)
M.read=function()error('corrupt')end;assert(M.snapshot().code=='control_unreadable')
M.read=savedRead;package.loaded['schoolbell.media_fs']=original
local S=require('schoolbell.schedule_store')
local d=S.empty();assert(d.mode=='fixed' and d.fixed_schedule=='quiet' and d.manual_media=='test')
d.schedules={{id='normal',name='Normal',rows={{id='r',time='08:00',media='1',pre=true,enabled=true}}}};d.fixed_schedule='normal';d.manual_media='4';d.pre_media='0'
local text=C.encode(d);assert(S.validate(text));local out=S.preview(text,'2026-10-25');assert(out.ok and #out.events==2 and out.events[1].media=='0' and out.events[2].media=='1')
d.mode='annual';d.plans=nil;out=S.preview(C.encode(d),'2026-10-25');assert(out.ok and #out.events==0)
d.manual_media='../evil';assert(not S.validate(C.encode(d)))
print('PASS controls: durable generation, idempotent mute, corrupt state, fixed/quiet/annual fallback, media whitelist')

local method,length,status,security='POST','2048',nil,0
package.loaded['luci.http']={getenv=function(k)if k=='REQUEST_METHOD'then return method elseif k=='CONTENT_LENGTH'then return length else return 'application/x-www-form-urlencoded'end end,status=function(v)status=v end,formvalue=function()error('must not parse')end}
package.loaded['luci.dispatcher']={test_post_security=function()security=security+1;return false end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
luci.controller.schoolbell_test.controls();assert(status==413 and security==0)
length='100';luci.controller.schoolbell_test.controls();assert(security==1)
method='PUT';luci.controller.schoolbell_test.controls();assert(status==405)
luci.controller.schoolbell_test.manual();assert(security==2)
print('PASS controls HTTP: bounds, method and CSRF before mutation/playback')

assert(not pcall(M.decode,'{"muted":false,"generation":0,"volume_db":false}'))

local form,calls,out={volume_db='-12'},0,nil
package.loaded['luci.http']={getenv=function(k)if k=='REQUEST_METHOD'then return 'POST' elseif k=='CONTENT_LENGTH'then return '64' else return 'application/x-www-form-urlencoded'end end,header=function()end,prepare_content=function()end,write=function(raw)out=C.decode(raw)end,formvalue=function(k)return form[k]end}
package.loaded['luci.dispatcher']={test_post_security=function()return true end}
package.loaded['nixio.fs']={lstat=function()return nil end}
package.loaded['schoolbell.sound_test']={lock='/test-lock'}
package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
package.loaded['schoolbell.controls']={request=function(value,host,volume)assert(value==nil and host==nil and volume==-12);calls=calls+1;return {ok=true,muted=false,generation=0,volume_db=volume}end}
luci.controller.schoolbell_test.controls();assert(calls==1 and out.volume_db==-12)
for _,v in ipairs({'1','-61','-1.5','0; touch /tmp/no','false'})do form={volume_db=v};luci.controller.schoolbell_test.controls();assert(not out.ok and calls==1)end
form={volume_db='-12',muted='true'};luci.controller.schoolbell_test.controls();assert(not out.ok and calls==1)
print('PASS volume HTTP: separate bounded numeric field; rejects mixed mutations and command text')
