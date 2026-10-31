-- schoolbell isolated model, NOT a native binding or OS backend.
-- Every supplied primitive represents one system operation. No default backend.
local codec = require("schoolbell.player_codec")
local M = {}
local MAX = 9007199254740991
local function int(n,l,h)
    return type(n)=="number" and n==n and n>=l and n<=h and n==math.floor(n)
end
local function plain(t) return type(t)=="table" and getmetatable(t)==nil end
local function fields(t, allowed)
    if not plain(t) then return false end
    for k in pairs(t) do if not allowed[k] then return false end end
    return true
end
local function ident(s)
    return type(s)=="string" and #s>=1 and #s<=64 and s:match("^[A-Za-z0-9_-]+$")~=nil
end
local function error_value(code,stage,errno)
    return {code=code,stage=stage,errno=int(errno,1,4095) and errno or nil}
end
local function fail(code,stage,errno) return nil,error_value(code,stage,errno) end
local function copy(t)
    local out={}
    for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end
    return out
end
-- Pure counter also permits boundary tests without billions of attempts.
function M.counter(last)
    if not int(last,0,4294967295) then return nil end
    return function()
        if last==4294967295 then return fail("limit","validate") end
        last=last+1; return last
    end
end
local setup_names={open=true,fstat=true,flock=true,pipe=true,fcntl=true,dup=true,close=true}
local child_names={dup=true,fcntl=true,close=true,exec=true,write=true,exit=true}
local cleanup_names={close=true}
local function budget(sys, maximum, allowed)
    local stats={calls=0,exhausted=false}
    local active=true
    local function call(name,...)
        if not active or not allowed[name] or type(sys[name])~="function" then
            error("invalid primitive")
        end
        if stats.calls==maximum then stats.exhausted=true; error("operation budget") end
        stats.calls=stats.calls+1
        return sys[name](...)
    end
    return call,stats,function() active=false end
end
function M.child_setup(sys, routine, token)
    if not plain(sys) or type(routine)~="function" then return fail("invalid_argument","validate") end
    local call,stats,seal=budget(sys,64,child_names)
    local ok,result=pcall(routine,call,token)
    seal()
    return {ok=ok and result==true and not stats.exhausted,calls=stats.calls,exhausted=stats.exhausted}
end
function M.new(sys, options)
    if not plain(sys) or not fields(options,{resources=true,max_records=true,launch_timeout_ms=true}) or
       not plain(options.resources) then return fail("invalid_argument","validate") end
    local max_records=options.max_records
    if max_records==nil then max_records=128 end
    local timeout=options.launch_timeout_ms
    if timeout==nil then timeout=2000 end
    if not int(max_records,1,128) or not int(timeout,100,60000) then return fail("invalid_argument","validate") end
    local resources,n={},0
    for k in pairs(options.resources) do
        n=n+1
        if not int(k,1,4) or n>4 then return fail("invalid_argument","validate") end
    end
    if n==0 then return fail("invalid_argument","validate") end
    for i=1,n do
        local id=options.resources[i]
        if not ident(id) or resources[id] then return fail("invalid_argument","validate") end
        resources[id]={}
    end
    local frozen={}
    for k,v in pairs(sys) do frozen[k]=v end
    sys=frozen
    for _,name in ipairs({"random","prepare","fork","clock","read","open_exe","fstat",
        "close","wait","cleanup","valid_signal"}) do
        if type(sys[name])~="function" then return fail("invalid_argument","validate") end
    end
    local ok,bytes=pcall(sys.random,16)
    if not ok or type(bytes)~="string" or #bytes~=16 then return fail("observe_failed","validate") end
    local generation=bytes:gsub(".",function(c) return string.format("%02x",c:byte()) end)
    local records,count,busy,last_mono={},0,false,nil
    local released=setmetatable({}, {__mode="k"})
    local next_id=M.counter(0)
    local api={}
    local function clock(call)
        local t=call("clock")
        if not int(t,0,MAX) or (last_mono and t<last_mono) then error("clock") end
        last_mono=t; return t
    end
    local function view(job) return copy(job.snapshot) end
    local function uncertain(job,code,stage,errno)
        job.poll_error=true
        job.snapshot.state="uncertain";job.snapshot.outcome="unknown"
        job.snapshot.error=error_value(code,stage,errno)
    end
    local function cleanup(job,maximum)
        local call,stats,seal=budget(sys,maximum or 8,cleanup_names)
        local ok,done=pcall(sys.cleanup,call,job.token)
        seal()
        job.snapshot.cleanup_pending=not (ok and done==true and not stats.exhausted)
        if job.snapshot.cleanup_pending then
            job.snapshot.error=error_value("cleanup_failed","cleanup")
        end
        return not job.snapshot.cleanup_pending,stats
    end
    function api.begin(request,media,permit)
        if busy then return fail("busy","validate") end
        if not fields(request,{resource=true}) or not resources[request.resource] or
           media==nil or type(permit)~="function" then return fail("invalid_argument","validate") end
        local resource=resources[request.resource]
        if resource.job then return fail("busy","lock") end
        if count==max_records then return fail("limit","validate") end
        local id,err=next_id();if not id then return nil,err end
        local handle={} -- identity only; mutations to this table cannot alter private state
        local job={token={},resource=resource,decoder=codec.decoder(),
            snapshot={generation=generation,attempt_id=id,state="launching",exec_status="pending",
                launch_timeout=false,cleanup_pending=true}}
        records[handle]=job;resource.job=job;count=count+1
        busy=true
        local names={}
        for k,v in pairs(setup_names) do names[k]=v end
        names.clock=true;names.fork=true
        local call,stats,seal=budget(sys,64,names)
        local stage="media"
        local ok,result=pcall(function()
            -- prepare cannot call fork: only this model may authorize that operation.
            local function prepare_call(name,...)
                if not setup_names[name] then error("prepare primitive") end
                -- Reserve clock and fork before giving preparation the remaining budget.
                if stats.calls>=62 then stats.exhausted=true;error("preparation budget") end
                return call(name,...)
            end
            local prepared,errno=sys.prepare(prepare_call,job.token,media,request.resource)
            if stats.exhausted then return error_value("limit","media") end
            if not plain(prepared) or not int(prepared.dev,0,MAX) or not int(prepared.ino,0,MAX) then
                return error_value("media_invalid","media",errno)
            end
            job.executable={dev=prepared.dev,ino=prepared.ino}
            stage="permit"
            local t=clock(call)
            if timeout>MAX-t then return error_value("limit","permit") end
            local permit_ok,granted=pcall(permit)
            if not permit_ok or granted~=true then return error_value("permit_denied","permit") end
            job.deadline=t+timeout
            stage="fork";job.possible=true
            local pid,errno=call("fork",job.token)
            if pid==false then job.possible=false;return error_value("spawn_failed","fork",errno) end
            if not int(pid,1,2147483647) then error("fork result") end
            job.pid=pid
        end)
        seal()
        if not ok or result then
            local e=result
            if not ok then
                e=error_value(stats.exhausted and "limit" or
                    (stage=="permit" and "clock_error" or
                     (stage=="media" and "media_invalid" or "spawn_failed")),stage)
            end
            if job.possible then
                uncertain(job,e.code,e.stage,e.errno)
            else
                job.snapshot.state="terminal";job.snapshot.exec_status="failed"
                job.snapshot.outcome="not_started";job.snapshot.error=e
                job.eof=true;job.reaped=true
                local done=cleanup(job,math.min(8,64-stats.calls))
                if done then
                    records[handle]=nil;resource.job=nil;count=count-1;busy=false
                    return nil,e
                end
            end
        end
        busy=false
        return handle
    end
    function api.poll(handle)
        if busy then return fail("busy","observe") end
        local job=records[handle]
        if not job then return fail(released[handle] and "stale_handle" or "invalid_handle","validate") end
        if job.reaped and (job.eof or job.protocol_failed) then
            return view(job),nil,{calls=0}
        end
        busy=true;job.poll_error=false
        local call,stats,seal=budget(sys,8,{clock=true,read=true,open_exe=true,fstat=true,close=true,wait=true})
        local ok=pcall(function()
            local time_ok,t=pcall(clock,call)
            if not time_ok then uncertain(job,"clock_error","observe") end
            if not job.eof and not job.protocol_failed then
                local chunk,reason=call("read",job.token,16)
                if type(chunk)=="string" then
                    local result=job.decoder.feed(chunk,chunk=="")
                    if not result then
                        job.protocol_failed=true;job.frame=nil
                        if job.snapshot.exec_status=="failed" then job.snapshot.exec_status="unknown" end
                        uncertain(job,"protocol_error","pipe")
                    else
                        job.eof=result.eof
                        if result.frame and job.snapshot.exec_status=="confirmed" then
                            job.protocol_failed=true;uncertain(job,"protocol_error","pipe")
                        elseif result.frame then
                            job.frame=result.frame
                            job.snapshot.exec_status="failed"
                            job.snapshot.error=error_value(result.frame.stage=="exec" and "exec_failed" or
                                "spawn_failed",result.frame.stage,result.frame.errno)
                        end
                    end
                elseif chunk~=nil or reason~="again" then uncertain(job,"observe_failed","pipe",reason) end
            end
            -- Observe before wait: never inspect a PID after it has been reaped.
            if job.pid and not job.reaped and not job.observation_lost and not job.frame and not job.protocol_failed and
               job.snapshot.exec_status~="confirmed" then
                local fd=call("open_exe",job.token,job.pid)
                if fd then
                    local stat_ok,st=pcall(call,"fstat",fd)
                    call("close",fd) -- close even if injected fstat throws
                    if stat_ok and plain(st) and st.dev==job.executable.dev and st.ino==job.executable.ino then
                        job.snapshot.exec_status="confirmed"
                    end
                end
            end
            if job.pid and not job.reaped then
                local result,errno=call("wait",job.pid)
                if plain(result) and result.kind=="exit" and int(result.code,0,255) then
                    job.reaped=true;job.exit={kind="exit",code=result.code}
                elseif plain(result) and result.kind=="signal" and int(result.signal,1,MAX) and
                       sys.valid_signal(result.signal)==true then
                    job.reaped=true;job.exit={kind="signal",signal=result.signal}
                elseif result~="running" then
                    job.observation_lost=true;uncertain(job,"observe_failed","observe",errno)
                end
            end
            if time_ok and job.deadline and t>=job.deadline and job.snapshot.exec_status=="pending" then
                job.snapshot.launch_timeout=true;job.snapshot.exec_status="unknown"
                uncertain(job,"launch_timeout","observe")
            end
            if job.reaped then
                job.snapshot.state="terminal"
                if job.snapshot.exec_status=="pending" then job.snapshot.exec_status="unknown" end
                if job.frame then
                    job.snapshot.outcome="not_started";job.snapshot.exit_code=nil;job.snapshot.signal=nil
                elseif job.exit then
                    job.snapshot.outcome=job.exit.kind;job.snapshot.exit_code=job.exit.code
                    job.snapshot.signal=job.exit.signal
                end
            elseif job.snapshot.exec_status=="confirmed" and not job.protocol_failed and not job.poll_error then
                job.snapshot.state="running";job.snapshot.outcome=nil
            end
        end)
        seal()
        if not ok then job.observation_lost=true;uncertain(job,"observe_failed","observe") end
        busy=false
        return view(job),nil,{calls=stats.calls}
    end
    function api.release(handle)
        if busy then return fail("busy","cleanup") end
        local job=records[handle]
        if not job then return fail(released[handle] and "stale_handle" or "invalid_handle","validate") end
        if not job.reaped then return fail("not_terminal","cleanup") end
        if not job.eof and not job.protocol_failed then return fail("busy","pipe") end
        busy=true;local done,stats=cleanup(job);busy=false
        if not done then return nil,error_value("cleanup_failed","cleanup"),stats end
        records[handle]=nil;released[handle]=true;job.resource.job=nil;count=count-1
        return true,nil,stats
    end
    return api
end
return M
