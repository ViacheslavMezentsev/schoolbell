local S=require("schoolbell.schedule_store")
local C=require("schoolbell.media_codec")
local J=require("modbus.json_strict")
local count=0
local function test(name,f) f();count=count+1;print("PASS annual editor: "..name)end
local original='{"pre_minutes":5,"pre_media":"test","schedules":[{"id":"day","name":"Day","rows":[{"id":"r1","time":"08:00","media":"test","enabled":true,"pre":true}]}]}'
local function data()return assert(J.decode(original))end
local function plan(d,y,days) d.plans=assert(J.decode("[]"));d.plans[1]={year=y,schedule_ids={"day"},days=days};return C.encode(d)end
test("legacy bytes and revision stay unchanged",function()
 local d,body=S.validate(original);assert(d and not d.plans)
 assert(body==C.encode(assert(J.decode(original))))
end)
test("full leap year fits and resolves Feb 29",function()
 local text=plan(data(),2028,string.rep("A",366));assert(#text<12288)
 local p=S.preview(text,"2028-02-29");assert(p.ok and #p.events==2 and p.events[1].time=="07:55")
 assert(p.clock_basis=="civil" and p.events[1].utc==nil and p.active==false)
end)
test("unassigned day and missing next year are quiet",function()
 local text=plan(data(),2026,"A"..string.rep(".",364))
 assert(#S.preview(text,"2026-01-02").events==0)
 assert(#S.preview(text,"2027-01-01").events==0)
end)
test("quiet previous day suppresses crossing preliminary only",function()
 local d=data();d.schedules[1].rows[1].time="00:03"
 local text=plan(d,2026,".A"..string.rep(".",363))
 assert(#S.preview(text,"2026-01-01").events==0)
 local next=S.preview(text,"2026-01-02");assert(#next.events==1 and next.events[1].kind=="main")
end)
test("audible previous day includes next day's preliminary",function()
 local d=data();d.schedules[1].rows[1].time="00:03"
 local p=S.preview(plan(d,2026,"AA"..string.rep(".",363)),"2026-01-01")
 assert(p.ok and #p.events==2 and p.events[2].time=="23:58" and p.events[2].origin_date=="2026-01-02")
end)
test("Dec to Jan across explicitly assigned years",function()
 local d=data();d.schedules[1].rows[1].time="00:03";plan(d,2026,string.rep("A",365))
 d.plans[2]={year=2027,schedule_ids={"day"},days="A"..string.rep(".",364)}
 local p=S.preview(C.encode(d),"2026-12-31")
 assert(p.ok and p.events[#p.events].origin_date=="2027-01-01")
end)
test("disabled rows and empty schedules stay quiet",function()
 local d=data();d.schedules[1].rows[1].enabled=false
 assert(#S.preview(plan(d,2026,string.rep("A",365)),"2026-01-01").events==0)
 d.schedules[1].rows=assert(J.decode("[]"))
 assert(#S.preview(plan(d,2026,string.rep("A",365)),"2026-01-01").events==0)
end)
test("reject malformed lengths years codes references and duplicate palette",function()
 for _,change in ipairs({
  function(p)p.days=string.rep("A",366)end,
  function(p)p.year=10000 end,
  function(p)p.days="Q"..string.rep(".",364)end,
  function(p)p.days="a"..string.rep(".",364)end,
  function(p)p.schedule_ids={"missing"}end,
  function(p)p.schedule_ids={"day","day"}end,
  function(p)p.extra=true end})do
   local d=data();plan(d,2026,string.rep("A",365));change(d.plans[1]);assert(not S.validate(C.encode(d)))
 end
end)
test("fractional year rejected from wire JSON",function()
 local text=plan(data(),2026,string.rep("A",365)):gsub('"year":2026','"year":2026.5')
 assert(not S.validate(text))
end)
test("no referenced schedule deletion",function()
 local d=data();plan(d,2026,string.rep("A",365));d.schedules=assert(J.decode("[]"))
 assert(not S.validate(C.encode(d)))
end)
test("eight year bound and duplicate years",function()
 local d=data();plan(d,2026,string.rep(".",365))
 d.plans[2]=d.plans[1];assert(not S.validate(C.encode(d)))
 d.plans=assert(J.decode("[]"))
 for i=1,9 do local y=2020+i;d.plans[i]={year=y,schedule_ids={"day"},days=string.rep(".",(y%4==0)and 366 or 365)}end
 assert(not S.validate(C.encode(d)));d.plans[9]=nil;assert(S.validate(C.encode(d)))
end)
test("bad date rejected; Gregorian century and boundary",function()
 local text=plan(data(),2100,string.rep("A",365));assert(not S.preview(text,"2100-02-29").ok)
 assert(S.preview(text,"2100-03-01").ok)
 assert(S.preview(plan(data(),1,string.rep("A",365)),"0001-01-01").ok)
 assert(S.preview(plan(data(),9999,string.rep("A",365)),"9999-12-31").ok)
end)
print("annual editor: "..count.." groups passed")

-- TC-143: named ranges share the same date assignment semantics as legacy years.
test("named multi-year range and inclusive endpoints",function()
 local d=data();d.mode='annual';d.plans={{id='academic',name='Учебный год',start='2026-12-31',["end"]='2028-01-01',schedule_ids={'day'},days=string.rep('A',367)}}
 local text=C.encode(d);assert(S.validate(text))
 for _,date in ipairs({'2026-12-31','2027-06-01','2028-01-01'})do assert(#S.preview(text,date).events==2,date)end
 assert(#S.preview(text,'2026-12-30').events==0);assert(#S.preview(text,'2028-01-02').events==0)
end)
test("legacy checkpoint body unchanged; equivalent range previews",function()
 local d=data();local legacy=plan(d,2028,string.rep('A',366));local _,body=S.validate(legacy);assert(body==C.encode(d))
 d.plans[1]={id='year-2028',name='План 2028',start='2028-01-01',["end"]='2028-12-31',schedule_ids={'day'},days=string.rep('A',366)}
 for _,date in ipairs({'2028-01-01','2028-02-29','2028-12-31'})do assert(C.encode(S.preview(legacy,date))==C.encode(S.preview(C.encode(d),date)))end
end)
test("ranges reject overlap mixed shape bad names ids dates and codes",function()
 local d=data();d.plans={{id='x',name='Plan',start='2026-12-31',["end"]='2027-01-01',schedule_ids={'day'},days='AA'}}
 local good=C.encode(d)
 for _,change in ipairs({
 function(p)p.year=2026 end,function(p)p.id='bad/id'end,function(p)p.name=' 'end,
 function(p)p.start='2026-02-29'end,function(p)p["end"]='2026-01-01'end,function(p)p.days='A'end,
 function(p)p.days='AZ'end,function(p)p.schedule_ids={'missing'}end})do
 local x=assert(J.decode(good));change(x.plans[1]);assert(not S.validate(C.encode(x)))
 end
 d.plans[2]={id='y',name='Other',start='2027-01-01',["end"]='2027-01-02',schedule_ids={'day'},days='AA'};assert(not S.validate(C.encode(d)))
 d.plans[2].start='2027-01-02';d.plans[2]["end"]='2027-01-03';assert(S.validate(C.encode(d)))
end)
test("no fixed day quota and data size limit still enforced",function()
 local d=data();local n=assert(require('schoolbell.calendar').ordinal('2046-05-31'))-assert(require('schoolbell.calendar').ordinal('2026-09-01'))+1
 d.plans={{id='long',name='Long',start='2026-09-01',["end"]='2046-05-31',schedule_ids={'day'},days=string.rep('.',n)}}
 assert(n>2928 and S.validate(C.encode(d)))
 d.plans[1].days=string.rep('.',13000);local v,e=S.validate(C.encode(d));assert(not v and e.code=='size')
end)
test("pre-bell crosses range boundary only into an audible day",function()
 local d=data();d.schedules[1].rows[1].time='00:03';d.plans={{id='a',name='A',start='2026-12-31',["end"]='2026-12-31',schedule_ids={'day'},days='A'},{id='b',name='B',start='2027-01-01',["end"]='2027-01-01',schedule_ids={'day'},days='A'}}
 local p=S.preview(C.encode(d),'2026-12-31');assert(#p.events==2 and p.events[2].origin_date=='2027-01-01')
 d.plans[1].days='.';assert(#S.preview(C.encode(d),'2026-12-31').events==0);assert(#S.preview(C.encode(d),'2027-01-01').events==1)
end)
