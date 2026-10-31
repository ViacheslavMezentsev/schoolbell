-- Inactive editor draft. No player, scheduler, cron, UCI or core calls.
local J=require("modbus.json_strict")
local C=require("schoolbell.media_codec")
local Calendar=require("schoolbell.calendar")
local Media=require("schoolbell.media_ids")
local M={max_bytes=12288, file_bytes=16384}
local function array(n) return assert(J.decode(n or "[]")) end
local function fail(code,path) error({code=code,path=path},0) end
local function object(t,fields,path)
    if J.kind(t)~="object" then fail("object",path) end
    for k in pairs(t) do if fields[k]==nil then fail("unknown_field",path.."."..tostring(k)) end end
    for k,required in pairs(fields) do if required and t[k]==nil then fail("missing_field",path.."."..k) end end
end
local function expand_plans(d)
    if d.plans==nil then return {} end -- legacy drafts are read without rewriting
    if J.kind(d.plans)~="array" or #d.plans>8 then fail("limit","plans") end
    local ids,plan_ids,ranges,out={},{},{},{}
    for _,schedule in ipairs(d.schedules) do ids[schedule.id]=true end
    for i,p in ipairs(d.plans) do
        local path="plans."..i
        local first,last
        if p.year~=nil then
            object(p,{year=true,schedule_ids=true,days=true},path)
            if not C.integer(p.year,1,9999) then fail("year",path) end
            local legacy_id="year-"..p.year
            if plan_ids[legacy_id] then fail("id",path) end
            plan_ids[legacy_id]=true
            first,last=string.format("%04d-01-01",p.year),string.format("%04d-12-31",p.year)
        else
            object(p,{id=true,name=true,start=true,["end"]=true,schedule_ids=true,days=true},path)
            if type(p.id)~="string" or #p.id<1 or #p.id>64 or not p.id:match("^[A-Za-z0-9_-]+$") or plan_ids[p.id] then fail("id",path..".id") end
            plan_ids[p.id]=true
            if type(p.name)~="string" or #p.name<1 or #p.name>96 or p.name:find("[%z\1-\31\127]") or not p.name:find("%S") then fail("name",path..".name") end
            first,last=p.start,p["end"]
        end
        local a,b=Calendar.ordinal(first),Calendar.ordinal(last)
        if not a or not b or b<a then fail("date_range",path) end
        for _,v in ipairs(ranges)do if a<=v[2] and b>=v[1]then fail("overlap",path)end end
        ranges[#ranges+1]={a,b}
        if J.kind(p.schedule_ids)~="array" or #p.schedule_ids>16 then fail("limit",path..".schedule_ids") end
        local seen={}
        for _,id in ipairs(p.schedule_ids) do
            if type(id)~="string" or not ids[id] or seen[id] then fail("schedule_reference",path) end
            seen[id]=true
        end
        if type(p.days)~="string" or #p.days~=b-a+1 then fail("days",path) end
        local days,date={},first
        for day=1,#p.days do
            local char=p.days:sub(day,day)
            if char~="." then
                local slot=char:byte()-64
                if slot<1 or slot>#p.schedule_ids then fail("day_code",path) end
                days[date]=p.schedule_ids[slot]
            end
            if day<#p.days then date=assert(Calendar.add_days(date,1)) end
        end
        out[i]={start=first,["end"]=last,days=days}
    end
    return out
end
function M.validate(text)
    if type(text)~="string" or #text>M.max_bytes then return nil,{code="size"} end
    local d,e=J.decode(text)
    if not d then return nil,{code="json",path=e.code} end
    local ok,why=pcall(function()
        object(d,{schedules=true,pre_minutes=true,pre_media=true,plans=false,mode=false,fixed_schedule=false,manual_media=false},"draft")
        if J.kind(d.schedules)~="array" or #d.schedules>16 then fail("limit","schedules") end
        if not Media.valid(d.pre_media) then fail("media_reference","pre_media") end
        if d.mode~=nil and d.mode~='fixed' and d.mode~='annual' then fail('mode','mode')end
        if d.manual_media~=nil and not Media.valid(d.manual_media)then fail('media_reference','manual_media')end
        local schedules={}
        for i,s in ipairs(d.schedules) do
            local path="schedules."..i
            object(s,{id=true,name=true,rows=true,color=false},path)
            if s.color~=nil and not C.integer(s.color,1,16) then fail("color",path..".color") end
            if type(s.name)~="string" or #s.name<1 or #s.name>96
               or s.name:find("[%z\1-\31\127]") or not s.name:find("%S") then fail("name",path..".name") end
            if J.kind(s.rows)~="array" then fail("limit",path..".rows") end
            for j,row in ipairs(s.rows) do
                object(row,{id=true,time=true,media=true,enabled=true,pre=true},path..".rows."..j)
            end
            schedules[i]={id=s.id,rows=s.rows}
        end
        local valid,err=Calendar.validate({revision="editor",mode=d.mode or "annual",fixed_schedule=d.fixed_schedule or "quiet",timezone="UTC",
            pre_minutes=d.pre_minutes,pre_media=d.pre_media,media=Media.references(d),
            schedules=schedules,plans=expand_plans(d)})
        if not valid then fail(err.code,err.path) end
    end)
    if not ok then return nil,type(why)=="table" and why or {code="invalid"} end
    local encoded=C.encode(d)
    if #encoded>M.max_bytes then return nil,{code="size"} end
    return d,encoded
end
function M.preview(text,date)
    local d,body=M.validate(text)
    if not d then return {ok=false,code="invalid",detail=body} end
    local schedules={}
    for i,s in ipairs(d.schedules) do schedules[i]={id=s.id,rows=s.rows} end
    local mode=d.mode or 'annual'
    local fixed=d.fixed_schedule or 'quiet'
    local model,err=Calendar.compile({revision="preview",mode=mode,fixed_schedule=fixed,timezone="civil",
        pre_minutes=d.pre_minutes,pre_media=d.pre_media,media=Media.references(d),
        schedules=schedules,plans=expand_plans(d)})
    if not model then return {ok=false,code="invalid",detail=err} end
    -- Offset zero is an arithmetic coordinate for wall times, not UTC or a router zone.
    local preview,why=model.calculate(date,date,assert(Calendar.fixed_offset("civil",0)))
    if not preview then return {ok=false,code="preview",detail=why} end
    local events=array()
    for _,event in ipairs(preview.events) do
        events[#events+1]={date=event.date,time=event.time,origin_date=event.origin_date,
            schedule_id=event.schedule_id,row_id=event.row_id,kind=event.kind,media=event.media}
    end
    return {ok=true,active=false,clock_basis="civil",date=date,
        selected_schedule=preview.days[1].schedule_id,events=events}
end
function M.empty()
    return {schedules=array(),pre_minutes=2,pre_media="test",manual_media="test",mode="fixed",fixed_schedule="quiet"}
end
local function read(fs)
    local raw=fs.read("current.json",M.file_bytes)
    if not raw then
        -- Missing current with a previous checkpoint is never a fresh installation.
        if fs.stat("previous.json") then fail("recovery_required") end
        return {ok=true,revision="empty",data=M.empty(),active=false}
    end
    local saved=C.decode(raw)
    object(saved,{data=true,checksum=true},"checkpoint")
    local data,body=M.validate(C.encode(saved.data))
    if not data or not C.hex(saved.checksum,64) or C.sha(body)~=saved.checksum then fail("recovery_required") end
    return {ok=true,revision=saved.checksum,data=data,active=false},raw
end
function M.load(fs)
    local ok,result=pcall(read,fs)
    return ok and result or {ok=false,code="recovery_required"}
end
function M.save(fs,text,expected)
    local data,body=M.validate(text)
    if not data then return {ok=false,code="invalid",detail=body} end
    if type(expected)~="string" or (expected~="empty" and not C.hex(expected,64)) then
        return {ok=false,code="revision"}
    end
    local ok,result=pcall(function()
        local current,old=read(fs)
        if expected~=current.revision then return {ok=false,code="conflict"} end
        local digest=C.sha(body)
        if digest==current.revision then current.unchanged=true; return current end
        local raw=C.encode({data=data,checksum=digest})
        if #raw>M.file_bytes then fail("size") end
        -- Fixed transient names under the exclusive FS lock. Never promote leftovers.
        for _,name in ipairs({"next.json","previous-next.json"}) do
            if fs.stat(name) then fs.unlink(name) end
        end
        local free,total=fs.space()
        local reserve=math.max(524288,math.ceil(total/10))
        -- Existing current/previous are already included in free; allow two new files
        -- plus directory/allocation overhead. ENOSPC is still handled after this check.
        if free<reserve+2*M.file_bytes+16384 then fail("space") end
        fs.write("next.json",raw); fs.sync("next.json")
        if old then
            fs.write("previous-next.json",old); fs.sync("previous-next.json")
            fs.rename("previous-next.json","previous.json"); fs.sync("")
        end
        fs.rename("next.json","current.json"); fs.sync("")
        local after=read(fs)
        if after.revision~=digest then fail("recovery_required") end
        return after
    end)
    if ok then return result end
    local code=type(result)=="table" and result.code
    -- A write/rename/sync error may have happened after commit; require a fresh GET.
    return {ok=false,code=code or "storage_uncertain"}
end
function M.request(root,operation,text,expected,host)
    local FS=require("schoolbell.media_fs")
    local ok,fs=pcall(FS.new,root,host)
    if not ok then
        local busy=type(fs)=="string" and (fs=="busy" or fs:match(": busy$"))
        return {ok=false,code=busy and "busy" or "storage_unavailable"}
    end
    local good,result=pcall(operation=="save" and M.save or M.load,fs,text,expected)
    local closed=pcall(fs.close)
    if not good or not closed then return {ok=false,code="storage_uncertain"} end
    return result
end
return M
