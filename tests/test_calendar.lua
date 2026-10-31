package.path="./src/lua/?.lua;"..package.path
local cal=require("schoolbell.calendar")
local original=dofile("tests/original_fixture.lua")
local count=0
local function test(name,fn) fn(); count=count+1; print("[schoolbell-calendar] OK "..name) end
local function copy(x)
    if type(x)~="table" then return x end
    local t={}; for k,v in pairs(x) do t[k]=copy(v) end; return t
end
local function base()
    return {revision="r1",mode="annual",timezone="UTC+05:00",pre_minutes=2,pre_media="0",
        media={"0","1","2","3","4","test"},
        schedules={{id="empty",rows={{id="off",time="08:00",media="0",enabled=false,pre=false}}},
                   {id="weekday",rows=copy(original)},
                   {id="saturday",rows={}}, {id="reserve1",rows={}}, {id="reserve2",rows={}}},
        plans={{year=2026,days={["2026-10-26"]="weekday",["2026-10-27"]="quiet"}}}}
end
local function bad(c,code)
    local result,err=cal.validate(c)
    assert(result==nil and err and err.code==code,err and err.code or "accepted")
end
local function rejected(fn,code)
    local result,err=fn(); assert(result==nil and err.code==code,err and err.code or "accepted")
end
-- schoolbell TC-36: strict snapshots, not persistence or core registration.
test("five original schedule slots, media and disabled row validate",function()
    assert(cal.validate(base()))
end)
test("strict HH:MM, date and century leap validation",function()
    for _,time in ipairs({"8:00","24:00","12:60","-1:00","00:0","00:00:00","12:30x",12}) do
        local c=base(); c.schedules[2].rows[1].time=time; bad(c,"time")
    end
    for _,date in ipairs({"2026-02-29","1900-02-29","2100-02-29","2026-04-31","0000-01-01","2026-13-01","2026-00-01","2026-01-00"}) do
        rejected(function() return cal.add_days(date,0) end,"date")
    end
    assert(cal.add_days("2000-02-29",1)=="2000-03-01")
    assert(cal.add_days("2024-03-01",-1)=="2024-02-29")
end)
test("Gregorian domain bounds and no host clock dependency",function()
    assert(cal.weekday("0001-01-01")==1)
    assert(cal.add_days("2026-12-31",1)=="2027-01-01")
    rejected(function() return cal.add_days("0001-01-01",-1) end,"date_range")
    rejected(function() return cal.add_days("9999-12-31",1) end,"date_range")
    rejected(function() return cal.add_days("2026-01-01",math.huge) end,"date_range")
    assert(cal.days_in_month(1900,2)==28 and cal.days_in_month(2000,2)==29)
    assert(cal.days_in_month(2100,2)==28 and cal.days_in_month(2400,2)==29)
end)
test("fixed offset is explicit and preserves quarter-hour offsets",function()
    assert(cal.fixed_offset("zero",0)("zero","1970-01-01","00:00")[1]==0)
    assert(cal.fixed_offset("east",345)("east","1970-01-01","00:00")[1]==-20700)
    assert(cal.fixed_offset("west",-210)("west","1970-01-01","00:00")[1]==12600)
    assert(cal.fixed_offset("zero",0)("other","1970-01-01","00:00")==nil)
    assert(cal.fixed_offset("bad",841)==nil)
end)
test("enabled/pre are booleans and all rows are validated",function()
    for _,field in ipairs({"enabled","pre"}) do
        local c=base(); c.schedules[1].rows[1][field]="on"; bad(c,"boolean")
    end
    local c=base(); c.schedules[1].rows[1].media="missing"; bad(c,"media_reference")
end)
test("all preliminary intervals 1 through 10, reject fractions and infinities",function()
    for n=1,10 do local c=base(); c.pre_minutes=n; assert(cal.validate(c)) end
    for _,n in ipairs({0,11,1.5,math.huge,0/0,"2"}) do local c=base(); c.pre_minutes=n; bad(c,"interval") end
end)
test("media, fixed schedule and plan references checked even when unused",function()
    local c=base(); c.pre_media="absent"; bad(c,"media_reference")
    c=base(); c.fixed_schedule="absent"; bad(c,"schedule_reference")
    c=base(); c.plans[1].days["2026-12-25"]="absent"; bad(c,"schedule_reference")
    c=base(); c.mode="fixed"; bad(c,"schedule_reference")
    c=base(); c.mode="auto"; bad(c,"mode")
end)
test("unknown fields, metatables, sparse arrays and duplicate IDs rejected",function()
    local c=base(); c.extra=true; bad(c,"unknown_field")
    c=base(); c.schedules[2].rows[1].extra=true; bad(c,"unknown_field")
    c=base(); setmetatable(c,{__index=function() error("must not execute") end}); bad(c,"type")
    c=base(); c.schedules[2].rows[1]=nil; bad(c,"array")
    c=base(); c.schedules[3].id="weekday"; bad(c,"duplicate")
    c=base(); c.schedules[2].rows[2].id="r01"; bad(c,"duplicate")
    c=base(); c.media[2]="0"; bad(c,"duplicate")
    c=base(); c.plans[2]=copy(c.plans[1]); bad(c,"duplicate")
end)
test("explicit plan years and timezone; no invalid date normalization",function()
    local c=base(); c.plans[1].days["2027-01-01"]="weekday"; bad(c,"year")
    c=base(); c.plans[1].days["2026-02-29"]="weekday"; bad(c,"date")
    c=base(); c.plans[1].year=2026.5; bad(c,"year")
    c=base(); c.timezone=nil; bad(c,"timezone")
    c=base(); c.timezone="Zone; execute"; bad(c,"timezone")
end)
test("input quotas are bounded and limits are returned by copy",function()
    local limits=cal.limits(); limits.schedules=99999; assert(cal.limits().schedules==16)
    local c=base(); c.schedules[2].rows={}
    for i=1,600 do c.schedules[2].rows[i]={id="x"..i,time="00:00",media="0",enabled=false,pre=false} end
    assert(cal.validate(c)); c.schedules[2].rows[601]=copy(c.schedules[2].rows[1]); bad(c,"duplicate")
    c=base(); c.plans={}
    for i=1,8 do c.plans[i]={year=2020+i,days={}} end
    assert(cal.validate(c)); c.plans[9]={year=2040,days={}}; bad(c,"limit")
end)


local resolve=assert(cal.fixed_offset("UTC+05:00",300))
local function compiled(c) local model,err=cal.compile(c); assert(model,err and err.code); return model end
local function calculate(model,first,last,zone)
    local result,err=model.calculate(first,last or first,zone or resolve)
    assert(result,err and (err.code..":"..tostring(err.path)))
    return result.events
end
local function simple(time,pre)
    local c=base(); c.mode="fixed"; c.fixed_schedule="weekday"
    c.schedules[2].rows={{id="bell",time=time,media="3",enabled=true,pre=pre}}
    return c
end
-- schoolbell TC-37: fixed/assigned annual days and original 15+6 data.
test("original weekday has all 15 main and 6 preliminary moments",function()
    local c=base(); local events=calculate(compiled(c),"2026-10-26")
    local expected={"07:55/main/0","08:00/main/3","08:45/main/1","08:53/pre/0",
        "08:55/main/3","09:40/main/1","09:58/pre/0","10:00/main/3",
        "10:45/main/1","11:03/pre/0","11:05/main/3","11:50/main/1",
        "12:08/pre/0","12:10/main/3","12:55/main/1","13:03/pre/0",
        "13:05/main/3","13:50/main/2","13:58/pre/0","14:00/main/3","14:45/main/2"}
    assert(#events==21)
    for i,e in ipairs(events) do assert(e.time.."/"..e.kind.."/"..e.media==expected[i]) end
end)
test("fixed mode ignores calendar date assignments",function()
    local c=base(); c.mode="fixed"; c.fixed_schedule="weekday"
    local m=compiled(c)
    local a,b=calculate(m,"2026-10-26"),calculate(m,"2027-01-01")
    assert(#a==21 and #b==21)
    for i,e in ipairs(a) do assert(e.time==b[i].time and e.media==b[i].media) end
end)
test("enabled and pre flags independently control row events",function()
    local c=simple("10:00",false); assert(#calculate(compiled(c),"2026-01-01")==1)
    c.schedules[2].rows[1].pre=true; assert(#calculate(compiled(c),"2026-01-01")==2)
    c.schedules[2].rows[1].enabled=false; assert(#calculate(compiled(c),"2026-01-01")==0)
    c.fixed_schedule="quiet"; assert(#calculate(compiled(c),"2026-01-01")==0)
end)
test("one through ten minute offsets cross hours correctly",function()
    for n=1,10 do
        local c=simple("10:00",true); c.pre_minutes=n; c.pre_media="4"
        local e=calculate(compiled(c),"2026-01-01")
        assert(e[1].time==string.format("09:%02d",60-n) and e[1].media=="4")
        assert(e[2].time=="10:00" and e[2].media=="3")
    end
end)
test("midnight pre-bell belongs to its main source date, month and year",function()
    local c=simple("00:03",true); c.pre_minutes=5
    local m=compiled(c)
    for _,pair in ipairs({{"2026-12-31","2027-01-01"},{"2024-02-29","2024-03-01"},{"2026-04-30","2026-05-01"}}) do
        local e=calculate(m,pair[1]); assert(#e==2)
        assert(e[1].kind=="main" and e[1].origin_date==pair[1])
        assert(e[2].kind=="pre" and e[2].date==pair[1] and e[2].origin_date==pair[2] and e[2].time=="23:58")
    end
end)
test("quiet previous day suppresses only the incoming pre-bell",function()
    local c=simple("00:03",true); c.mode="annual"; c.pre_minutes=5
    c.plans={{year=2026,days={["2026-01-01"]="quiet",["2026-01-02"]="weekday",["2026-01-03"]="quiet"}}}
    local m=compiled(c); assert(#calculate(m,"2026-01-01")==0)
    local e=calculate(m,"2026-01-02"); assert(#e==1 and e[1].kind=="main")
    c.plans[1].days["2026-01-01"]="empty"
    assert(#calculate(compiled(c),"2026-01-01")==0)
end)
test("compiled input and returned events cannot mutate future calculations",function()
    local c=simple("08:00",true); local m=compiled(c)
    c.schedules[2].rows[1].time="09:00"; c.pre_media="4"; c.revision="changed"
    local e=calculate(m,"2026-01-01"); e[1].time="23:59"; e[1].media="missing"
    local next_e=calculate(m,"2026-01-01")
    assert(next_e[1].time=="07:58" and next_e[1].media=="0" and next_e[1].revision=="r1")
    local invalid=copy(c); invalid.pre_minutes=0; assert(cal.compile(invalid)==nil)
    assert(calculate(m,"2026-01-01")[2].time=="08:00")
end)
test("coincident moments preserved with stable identities and ordering",function()
    local c=simple("08:00",false)
    c.schedules[2].rows[2]={id="second",time="08:00",media="4",enabled=true,pre=false}
    local m=compiled(c); local a,b=calculate(m,"2026-01-01"),calculate(m,"2026-01-01")
    assert(#a==2 and a[1].utc==a[2].utc and a[1].id~=a[2].id)
    for i=1,2 do assert(a[i].id==b[i].id) end
end)
test("window and output limits fail atomically",function()
    local c=base(); c.mode="fixed"; c.fixed_schedule="weekday"; local m=compiled(c)
    rejected(function() return m.calculate("2026-01-02","2026-01-01",resolve) end,"window")
    rejected(function() return m.calculate("2026-01-01","2026-02-01",resolve) end,"window")
    rejected(function() return m.calculate("2026-01-01","2026-01-31",resolve) end,"limit")
    assert(#calculate(m,"2026-01-01")==21)
end)

-- schoolbell TC-38: accepted missing-year/day, quiet midnight and timezone rules.
test("unassigned dates and absent years are quiet without annual repetition",function()
    local c=base(); local m=compiled(c)
    assert(#calculate(m,"2026-10-25")==0)
    assert(#calculate(m,"2027-10-26")==0)
    local out=assert(m.calculate("2027-10-26","2027-10-26",resolve))
    assert(out.days[1].schedule_id=="quiet" and out.revision=="r1")
    c.plans[2]={year=2027,days={["2027-10-26"]="weekday"}}
    assert(#calculate(compiled(c),"2027-10-26")==21)
end)
test("new year pre-bell requires an audible previous calendar day",function()
    local c=simple("00:03",true); c.mode="annual"; c.pre_minutes=5
    c.plans={{year=2027,days={["2027-01-01"]="weekday"}}}
    assert(#calculate(compiled(c),"2026-12-31")==0)
    local e=calculate(compiled(c),"2027-01-01"); assert(#e==1 and e[1].kind=="main")
    c.plans[2]={year=2026,days={["2026-12-31"]="weekday"}}
    e=calculate(compiled(c),"2026-12-31")
    assert(#e==2 and e[2].kind=="pre" and e[2].origin_date=="2027-01-01")
end)
test("full leap year preserves all original moments day by day",function()
    local c=base(); c.plans={{year=2024,days={}}}
    local date="2024-01-01"
    for i=1,366 do c.plans[1].days[date]="weekday"; date=assert(cal.add_days(date,1)) end
    local m=compiled(c); date="2024-01-01"; local total,ids=0,{}
    for i=1,366 do
        local e=calculate(m,date); assert(#e==21)
        for _,event in ipairs(e) do assert(not ids[event.id]); ids[event.id]=true end
        total=total+#e; date=assert(cal.add_days(date,1))
    end
    assert(total==7686 and date=="2025-01-01" and #calculate(m,date)==0)
end)
test("DST gap or fold rejects the whole window, not a partial preview",function()
    local m=compiled(simple("02:30",false))
    for _,case in ipairs({{values={},code="nonexistent_time"},{values={1,2},code="ambiguous_time"}}) do
        local calls=0
        local function resolver(zone,date,time)
            calls=calls+1
            if date=="2026-03-29" then return case.values end
            return resolve(zone,date,time)
        end
        rejected(function() return m.calculate("2026-03-28","2026-03-29",resolver) end,case.code)
        assert(calls==2)
        assert(#calculate(m,"2026-03-28")==1)
    end
end)
test("DST error applies to a preliminary moment; suppressed bells need no resolution",function()
    local c=simple("03:03",true); c.pre_minutes=5
    local function resolver(zone,date,time)
        if time=="02:58" then return {} end
        return resolve(zone,date,time)
    end
    local m=compiled(c)
    rejected(function() return m.calculate("2026-03-29","2026-03-29",resolver) end,"nonexistent_time")
    c.mode="annual"; c.schedules[2].rows[1].time="00:03"
    c.plans={{year=2026,days={["2026-01-02"]="weekday"}}}
    local function must_not_call() error("quiet day must not resolve any bell") end
    local out=assert(compiled(c).calculate("2026-01-01","2026-01-01",must_not_call))
    assert(#out.events==0)
end)
test("resolver failures, malformed values and missing callback fail explicitly",function()
    local m=compiled(simple("08:00",false))
    rejected(function() return m.calculate("2026-01-01","2026-01-01") end,"resolver")
    rejected(function() return m.calculate("2026-01-01","2026-01-01",function() error("unavailable") end) end,"resolver")
    rejected(function() return m.calculate("2026-01-01","2026-01-01",function() return nil,"zone unavailable" end) end,"resolver")
    for _,v in ipairs({math.huge,0/0,1.5,"123",0}) do
        rejected(function() return m.calculate("2026-01-01","2026-01-01",function() return {v} end) end,"resolver_result")
    end
    rejected(function() return m.calculate("2026-01-01","2026-01-01",function() return {[2]=1} end) end,"array")
end)
test("adjacent windows preserve identities including lookahead pre-bells",function()
    local m=compiled(simple("00:01",true))
    local a=calculate(m,"2026-12-31"); local b=calculate(m,"2027-01-01")
    local both=calculate(m,"2026-12-31","2027-01-01")
    assert(#both==#a+#b)
    for i,e in ipairs(a) do assert(e.id==both[i].id) end
    for i,e in ipairs(b) do assert(e.id==both[#a+i].id) end
end)
test("exact output budget succeeds and budget plus one is not truncated",function()
    local c=simple("08:00",false); c.schedules[2].rows={}
    for i=1,128 do c.schedules[2].rows[i]={id="x"..i,time="08:00",media="0",enabled=true,pre=false} end
    local m=compiled(c); assert(#calculate(m,"2026-01-01","2026-01-04")==512)
    rejected(function() return m.calculate("2026-01-01","2026-01-05",resolve) end,"limit")
end)
test("no total row cap and reserved quiet identifier",function()
    local c=simple("08:00",false); c.schedules={}; c.fixed_schedule="s1"
    c.plans={}
    for i=1,4 do
        c.schedules[i]={id="s"..i,rows={}}
        for j=1,128 do c.schedules[i].rows[j]={id="r"..j,time="08:00",media="0",enabled=false,pre=false} end
    end
    assert(cal.validate(c)); c.schedules[5]={id="overflow",rows={copy(c.schedules[1].rows[1])}}; assert(cal.validate(c))
    c=simple("08:00",false); c.schedules[2].id="quiet"; bad(c,"duplicate")
end)
test("date domain edges do not invent a pre-bell outside the supported range",function()
    local m=compiled(simple("00:01",true))
    local a=calculate(m,"0001-01-01"); assert(#a==2 and a[1].kind=="main")
    local b=calculate(m,"9999-12-31"); assert(#b==1 and b[1].kind=="main")
end)
print("[schoolbell-calendar] PASS: "..count.." groups")
