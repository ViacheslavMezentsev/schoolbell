local S=require("schoolbell.schedule_store")
local C=require("schoolbell.media_codec")
local J=require("modbus.json_strict")
local sample='{"schedules":[{"id":"work","name":"Рабочее","rows":[{"id":"r1","time":"08:00","media":"test","enabled":true,"pre":true}]}],"pre_minutes":2,"pre_media":"test"}'
local count=0
local function test(name,f) f(); count=count+1; print("PASS schedule store: "..name) end
local function fs()
 local disk={};local x={writes=0}
 x.read=function(n,max) local s=disk[n]; assert(not s or #s<=max);return s end
 x.stat=function(n)return disk[n] and {type="reg",size=#disk[n]} end
 x.write=function(n,s) assert(not disk[n]);x.writes=x.writes+1;disk[n]=s end
 x.sync=function()end
 x.rename=function(a,b)assert(disk[a]);disk[b]=disk[a];disk[a]=nil end
 x.unlink=function(n)disk[n]=nil end
 x.space=function()return 2000000,4000000 end
 x.disk=disk
 return x
end
test("valid schema matches calendar",function() assert(S.validate(sample)) end)
test("empty arrays remain arrays",function()
 local f=fs(); local a=S.load(f);assert(a.revision=="empty" and J.kind(a.data.schedules)=="array")
 assert(S.save(f,C.encode(a.data),"empty").ok)
 assert(J.kind(S.load(f).data.schedules)=="array")
end)
test("save reload previous and no-op",function()
 local f=fs();local a=S.save(f,sample,"empty");assert(a.ok and not a.active)
 local n=f.writes;assert(S.save(f,sample,a.revision).unchanged and f.writes==n)
 local b=S.save(f,sample:gsub("08:00","09:00"),a.revision);assert(b.ok and b.revision~=a.revision)
 assert(S.load(f).data.schedules[1].rows[1].time=="09:00")
 assert(C.decode(f.disk["previous.json"]).checksum==a.revision)
end)
test("stale editor cannot overwrite",function()
 local f=fs();assert(S.save(f,sample,"empty").ok);local n=f.writes
 assert(S.save(f,sample:gsub("08:00","09:00"),"empty").code=="conflict" and f.writes==n)
end)
test("invalid input never writes",function()
 for _,s in ipairs({sample:gsub("08:00","24:00"),sample:gsub('"enabled":true','"enabled":"true"'),
   sample:gsub('"pre_minutes":2','"pre_minutes":11'),sample:gsub('"media":"test"','"media":"other"'),
   sample:gsub('"name":"Рабочее"','"name":""'),sample:gsub('"id":"work"','"id":"quiet"'),
   sample:gsub('"rows":%[.-%]','"rows":{}'),sample:gsub('"pre_media":"test"','"pre_media":"test","extra":1'),
   '{"schedules":[],"schedules":[]}',string.rep(" ",S.max_bytes+1),
   sample:gsub('Рабочее',[[x\u0000y]])}) do
   local f=fs();assert(not S.save(f,s,"empty").ok and f.writes==0,s)
 end
end)
test("duplicates rejected including disabled rows",function()
 local d=assert(J.decode(sample));d.schedules[1].rows[2]=d.schedules[1].rows[1]
 assert(not S.validate(C.encode(d)))
 d=assert(J.decode(sample));d.schedules[2]=d.schedules[1];assert(not S.validate(C.encode(d)))
end)
test("schedule and name bounds remain; 33 rows admitted",function()
 local d=assert(J.decode(sample))
 for i=2,33 do d.schedules[1].rows[i]={id="r"..i,time="08:00",media="test",enabled=true,pre=false} end
 assert(S.validate(C.encode(d)))
 d=assert(J.decode(sample));d.schedules[1].name=string.rep("x",97);assert(not S.validate(C.encode(d)))
 d=assert(J.decode(sample));for i=2,17 do d.schedules[i]={id="s"..i,name="S",rows=assert(J.decode("[]"))} end
 assert(not S.validate(C.encode(d)))
end)
test("reserve before write",function()
 local f=fs();f.space=function() return 524288,4000000 end
 assert(S.save(f,sample,"empty").code=="space" and f.writes==0)
end)
test("corruption does not reset data",function()
 local f=fs();assert(S.save(f,sample,"empty").ok)
 f.disk["current.json"]=f.disk["current.json"]:gsub("08:00","09:00")
 assert(S.load(f).code=="recovery_required");local old=f.disk["current.json"]
 assert(not S.save(f,sample,"empty").ok and f.disk["current.json"]==old)
 f.disk["previous.json"]=old;f.disk["current.json"]=nil
 assert(S.load(f).code=="recovery_required")
end)
test("orphan temp never promoted",function()
 local f=fs();f.disk["next.json"]="garbage"
 assert(S.load(f).revision=="empty")
 assert(S.save(f,sample,"empty").ok)
end)
test("write failure leaves committed data",function()
 local f=fs();local a=S.save(f,sample,"empty");f.write=function()error("ENOSPC")end
 assert(S.save(f,sample:gsub("08:00","09:00"),a.revision).code=="storage_uncertain")
 assert(S.load(f).revision==a.revision)
end)
test("post-rename sync failure is uncertain not success",function()
 local f=fs();local a=S.save(f,sample,"empty");local calls=0
 f.sync=function(n)calls=calls+1;if calls==4 then error("sync")end end
 local out=S.save(f,sample:gsub("08:00","09:00"),a.revision)
 assert(out.code=="storage_uncertain" and not out.ok)
 assert(S.load(f).data.schedules[1].rows[1].time=="09:00")
end)
test("request distinguishes contention from missing/private/restore/I/O errors",function()
 local function host(lock,restore,root)
  return {stat=function(p)if p=="/test" then return root or {type="dir",mode=448} end;if restore and p=="/test/restore.pending" then return {type="reg"} end end,lock=lock}
 end
 assert(S.request("/test","load",nil,nil,host(function()return nil end)).code=="busy")
 assert(S.request("/test","load",nil,nil,host(function()error("I/O")end)).code=="storage_unavailable")
 assert(S.request("/test","load",nil,nil,host(function()error("must not lock")end,true)).code=="storage_unavailable")
 assert(S.request("/test","load",nil,nil,host(function()error("must not lock")end,false,{type="dir",mode=511})).code=="storage_unavailable")
end)
-- No HTTP token decoding or disk access for oversized bodies; failed CSRF cannot save.
local calls=0;local length="999999";local allowed=false;local status
package.loaded["luci.http"]={getenv=function(k)if k=="CONTENT_LENGTH" then return length end;if k=="CONTENT_TYPE" then return "application/x-www-form-urlencoded" end;return "POST" end,status=function(c)status=c end}
package.loaded["luci.dispatcher"]={test_post_security=function()calls=calls+1;return allowed end}
dofile("packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua")
test("HTTP body bound before form decoding",function()
 luci.controller.schoolbell_test.save_schedules();assert(status==413 and calls==0)
end)
test("CSRF rejected before storage",function()
 length="100";luci.controller.schoolbell_test.save_schedules();assert(calls==1)
end)
print("schedule store: "..count.." groups passed")

test("no row-count caps: 129 rows save and reload",function()
 local d=assert(S.validate(sample));d.schedules[1].rows=assert(J.decode('[]'))
 for i=1,129 do d.schedules[1].rows[i]={id='r'..i,time='09:00',media='test',enabled=true,pre=false} end
 local raw=C.encode(d);assert(#raw<=S.max_bytes)
 local f=fs();local result=S.save(f,raw,'empty');assert(result.ok,result.code)
 assert(#S.load(f).data.schedules[1].rows==129)
 d.schedules[1].rows[130]=d.schedules[1].rows[1]
 assert(not S.validate(C.encode(d)))
end)
