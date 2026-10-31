-- Pure Gregorian/calendar calculation for schoolbell. No clock, filesystem or core I/O.
local M = {}
local floor = math.floor
local LIMIT = {schedules=16, years=8, media=nil,
               window_days=31, events=512}
local function bad(code, path) error({code=code, path=path}, 0) end
local function integer(n, lo, hi)
    return type(n)=="number" and n==n and n>=lo and n<=hi and n==floor(n)
end
local function plain(t, path)
    if type(t)~="table" or getmetatable(t)~=nil then bad("type",path) end
end
local function object(t, fields, path)
    plain(t,path)
    for k in pairs(t) do if not fields[k] then bad("unknown_field",path) end end
end
local function array(t, maximum, path)
    plain(t,path)
    local n=0
    for k in pairs(t) do
        n=n+1
        if maximum and n>maximum then bad("limit",path) end
        if not integer(k,1,maximum or math.huge) then bad("array",path) end
    end
    for i=1,n do if rawget(t,i)==nil then bad("array",path) end end
    return n
end
local function id(s,path)
    if type(s)~="string" or #s<1 or #s>64 or not s:match("^[A-Za-z0-9_-]+$") then bad("id",path) end
    return s
end
local function leap(y) return y%4==0 and (y%100~=0 or y%400==0) end
local lengths={31,28,31,30,31,30,31,31,30,31,30,31}
local function month_days(y,m) return m==2 and leap(y) and 29 or lengths[m] end
local function before_year(y)
    y=y-1; return y*365+floor(y/4)-floor(y/100)+floor(y/400)
end
local MAX_DAY=before_year(10000)-1
local EPOCH_DAY=before_year(1970)
local function date_parts(s,path)
    if type(s)~="string" then bad("date",path) end
    local y,m,d=s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or y<1 or m<1 or m>12 or d<1 or d>month_days(y,m) then bad("date",path) end
    local ordinal=before_year(y)+d-1
    for i=1,m-1 do ordinal=ordinal+month_days(y,i) end
    return ordinal,y,m,d
end
local function day_string(n)
    if not integer(n,0,MAX_DAY) then bad("date_range","date") end
    local lo,hi=1,10000
    while lo+1<hi do
        local mid=floor((lo+hi)/2)
        if before_year(mid)<=n then lo=mid else hi=mid end
    end
    local rem,m=n-before_year(lo),1
    while rem>=month_days(lo,m) do rem=rem-month_days(lo,m); m=m+1 end
    return string.format("%04d-%02d-%02d",lo,m,rem+1)
end
local function minute(s,path)
    if type(s)~="string" then bad("time",path) end
    local h,m=s:match("^(%d%d):(%d%d)$"); h,m=tonumber(h),tonumber(m)
    if not h or h>23 or m>59 then bad("time",path) end
    return h*60+m
end
local function time_string(n) return string.format("%02d:%02d",floor(n/60),n%60) end
local function guarded(fn)
    local ok,value=pcall(fn)
    if ok then return value end
    if type(value)=="table" and value.code then return nil,value end
    return nil,{code="internal"}
end
function M.limits()
    local copy={}; for k,v in pairs(LIMIT) do copy[k]=v end; return copy
end
function M.ordinal(date) return guarded(function() return date_parts(date,"date") end) end
function M.days_in_month(year,month)
    return guarded(function()
        if not integer(year,1,9999) or not integer(month,1,12) then bad("date","month") end
        return month_days(year,month)
    end)
end
function M.add_days(date,delta)
    return guarded(function()
        if not integer(delta,-MAX_DAY,MAX_DAY) then bad("date_range","delta") end
        return day_string(date_parts(date,"date")+delta)
    end)
end
function M.weekday(date)
    return guarded(function() return date_parts(date,"date")%7+1 end) -- ISO Monday=1
end
-- Explicit fixed offset only: no implicit host timezone and no claim to implement tzdb.
function M.fixed_offset(zone,offset_minutes)
    if type(zone)~="string" or #zone<1 or #zone>64 or not integer(offset_minutes,-840,840) then
        return nil,{code="timezone"}
    end
    return function(requested,date,time)
        if requested~=zone then return nil,"unknown_timezone" end
        local d=date_parts(date,"resolver.date")
        local m=minute(time,"resolver.time")
        return {(d-EPOCH_DAY)*86400+m*60-offset_minutes*60}
    end
end

local function snapshot(config)
    object(config,{revision=true,mode=true,timezone=true,fixed_schedule=true,
                   pre_minutes=true,pre_media=true,media=true,schedules=true,plans=true},"config")
    local c={revision=id(config.revision,"revision"), mode=config.mode,
             timezone=config.timezone, schedules={}, plans={}, media={}}
    if c.mode~="fixed" and c.mode~="annual" then bad("mode","mode") end
    if type(c.timezone)~="string" or #c.timezone<1 or #c.timezone>64 or
       not c.timezone:match("^[A-Za-z0-9_+:/%-]+$") then bad("timezone","timezone") end
    if not integer(config.pre_minutes,1,10) then bad("interval","pre_minutes") end
    c.pre_minutes=config.pre_minutes
    local n=array(config.media,LIMIT.media,"media")
    if n==0 then bad("media","media") end
    for i=1,n do
        local value=id(config.media[i],"media")
        if c.media[value] then bad("duplicate","media") end
        c.media[value]=true
    end
    local function media(value,path)
        id(value,path); if not c.media[value] then bad("media_reference",path) end
        return value
    end
    c.pre_media=media(config.pre_media,"pre_media")
    n=array(config.schedules,LIMIT.schedules,"schedules")
    for i=1,n do
        local source=config.schedules[i]
        object(source,{id=true,rows=true},"schedule")
        local key=id(source.id,"schedule.id")
        if key=="quiet" or c.schedules[key] then bad("duplicate","schedule.id") end
        local target={rows={},audible=false}; c.schedules[key]=target
        local count=array(source.rows,nil,"rows")
        local seen={}
        for j=1,count do
            local row=source.rows[j]
            object(row,{id=true,time=true,media=true,enabled=true,pre=true},"row")
            local key_row=id(row.id,"row.id")
            if seen[key_row] then bad("duplicate","row.id") end
            seen[key_row]=true
            if type(row.enabled)~="boolean" or type(row.pre)~="boolean" then bad("boolean","row") end
            local value={id=key_row,time=row.time,minute=minute(row.time,"row.time"),
                         media=media(row.media,"row.media"),enabled=row.enabled,pre=row.pre}
            target.rows[j]=value
            if row.enabled then target.audible=true end
        end
    end
    local function schedule(value,path)
        id(value,path)
        if value~="quiet" and not c.schedules[value] then bad("schedule_reference",path) end
        return value
    end
    if config.fixed_schedule~=nil then c.fixed_schedule=schedule(config.fixed_schedule,"fixed_schedule") end
    if c.mode=="fixed" and not c.fixed_schedule then bad("schedule_reference","fixed_schedule") end
    n=array(config.plans,LIMIT.years,"plans")
    local occupied,legacy_years={},{}
    for i=1,n do
        local plan=config.plans[i]
        object(plan,{year=true,start=true,["end"]=true,days=true},"plan")
        local first,last
        if plan.year~=nil then
            if plan.start~=nil or plan["end"]~=nil or not integer(plan.year,1,9999) then bad("year","plan.year") end
            if legacy_years[plan.year] then bad("duplicate","plan.year") end
            legacy_years[plan.year]=true
            first,last=string.format("%04d-01-01",plan.year),string.format("%04d-12-31",plan.year)
        else first,last=plan.start,plan["end"] end
        local a,b=date_parts(first,"plan.start"),date_parts(last,"plan.end")
        if b<a then bad("date_range","plan") end
        for _,p in ipairs(occupied) do if a<=p[2] and b>=p[1] then bad("overlap","plan") end end
        occupied[#occupied+1]={a,b}
        local days={};plain(plan.days,"plan.days")
        for date,value in pairs(plan.days) do
            local day=date_parts(date,"plan.date")
            if day<a or day>b then bad("year","plan.date") end
            days[date]=schedule(value,"plan.schedule")
        end
        c.plans[i]={start=first,["end"]=last,days=days}
    end
    return c
end

function M.validate(config)
    return guarded(function() snapshot(config); return true end)
end
function M.compile(config)
    return guarded(function()
        local c=snapshot(config)
        local function selected(date)
            if c.mode=="fixed" then return c.fixed_schedule end
            date_parts(date,"date")
            for _,p in ipairs(c.plans) do
                if date>=p.start and date<=p["end"] then return p.days[date] or "quiet" end
            end
            return "quiet"
        end
        local function quiet(date)
            local sid=selected(date)
            return sid=="quiet" or not c.schedules[sid].audible
        end
        local api={}
        function api.calculate(first,last,resolver)
            return guarded(function()
                local start_day=date_parts(first,"first")
                local end_day=date_parts(last,"last")
                if end_day<start_day or end_day-start_day+1>LIMIT.window_days then bad("window","range") end
                if type(resolver)~="function" then bad("resolver","timezone") end
                local events,days={},{}
                local function append(origin,sid,row,kind,day,mins,media)
                    if day<start_day or day>end_day then return end
                    local date,time=day_string(day),time_string(mins)
                    -- schoolbell 3.3.2: a silent destination day suppresses an incoming pre-bell.
                    if kind=="pre" and quiet(date) then return end
                    if #events>=LIMIT.events then bad("limit","events") end
                    local ok,candidates=pcall(resolver,c.timezone,date,time)
                    if not ok or candidates==nil then bad("resolver","timezone") end
                    -- schoolbell 3.3.10: reject gaps/folds; never guess or normalize local time.
                    local n=array(candidates,2,"resolver.candidates")
                    if n==0 then bad("nonexistent_time",date.."T"..time) end
                    if n==2 then bad("ambiguous_time",date.."T"..time) end
                    local utc=candidates[1]
                    local local_seconds=(day-EPOCH_DAY)*86400+mins*60
                    if not integer(utc,local_seconds-86400,local_seconds+86400) then
                        bad("resolver_result","utc")
                    end
                    events[#events+1]={id=table.concat({c.revision,origin,sid,row.id,kind},"/"),
                        revision=c.revision,timezone=c.timezone,date=date,time=time,utc=utc,
                        origin_date=origin,schedule_id=sid,row_id=row.id,kind=kind,media=media}
                end
                -- Include the next source day: its pre-bell may belong to the requested last day.
                for day=start_day,math.min(end_day+1,MAX_DAY) do
                    local date=day_string(day)
                    local sid=selected(date)
                    if day<=end_day then days[#days+1]={date=date,schedule_id=sid} end
                    if sid~="quiet" then
                        for _,row in ipairs(c.schedules[sid].rows) do
                            if row.enabled then
                                append(date,sid,row,"main",day,row.minute,row.media)
                                if row.pre then
                                    local before=row.minute-c.pre_minutes
                                    local shift=floor(before/1440)
                                    append(date,sid,row,"pre",day+shift,before%1440,c.pre_media)
                                end
                            end
                        end
                    end
                end
                table.sort(events,function(a,b)
                    if a.utc~=b.utc then return a.utc<b.utc end
                    return a.id<b.id
                end)
                return {revision=c.revision,timezone=c.timezone,events=events,days=days}
            end)
        end
        return api
    end)
end
return M
