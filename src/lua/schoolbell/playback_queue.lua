-- Isolated schoolbell worker model; no processes, sound, filesystem or core API.
local M = {}
local MAX=9007199254740991
local function int(n,lo,hi) return type(n)=="number" and n==n and n>=lo and n<=hi and n==math.floor(n) end
local function plain(t) return type(t)=="table" and getmetatable(t)==nil end
local function id(s) return type(s)=="string" and #s>0 and #s<=64 and s:match("^[A-Za-z0-9_-]+$")~=nil end
local function fields(t,allowed)
    if not plain(t) then return false end
    for k in pairs(t) do if not allowed[k] then return false end end
    return true
end
local terminal={finished=true,failed=true,expired=true,cancelled=true}
local function err(code) return nil,{code=code} end
function M.new(clock,player,options,media)
    if type(clock)~="function" or not plain(player) or type(player.start)~="function" or
       type(player.poll)~="function" then return err("backend") end
    if not fields(options,{resources=true,max_records=true,max_pending=true}) or not plain(options.resources) then
        return err("options")
    end
    if media~=nil and (type(media)~="userdata" or type(media.acquire)~="function" or
        type(media.release)~="function") then return err("media_backend") end
    local acquire,drop=media and media.acquire,media and media.release
    local function release_media(job)
        if not job.media_lease then return true end
        local ok,result=pcall(drop,media,job.media_lease)
        if not ok or result~=true then return false end
        job.media_lease=false;return true
    end
    local maximum=options.max_records
    if maximum==nil then maximum=128 end
    local pending_max=options.max_pending
    if pending_max==nil then pending_max=32 end
    if not int(maximum,1,128) or not int(pending_max,1,32) then return err("options") end
    local order,resources={},{}
    local n=0
    for k in pairs(options.resources) do
        n=n+1; if n>4 or not int(k,1,4) then return err("resources") end
    end
    if n==0 then return err("resources") end
    for i=1,n do
        local name=options.resources[i]
        if not id(name) or resources[name] then return err("resources") end
        order[i]=name; resources[name]={pending={}}
    end
    -- Freeze backend function references and configuration; all external data is copied.
    local start,poll=player.start,player.poll
    local jobs,next_id,records,last_mono,busy={},0,0,nil,false
    local api={}
    local function now()
        local ok,t=pcall(clock)
        if not ok or not plain(t) or not int(t.mono_ms,0,MAX) or type(t.utc_valid)~="boolean" or
           (t.utc_valid and not int(t.utc_ms,-MAX,MAX)) then return nil,"clock" end
        if last_mono and t.mono_ms<last_mono then return nil,"clock_regressed" end
        last_mono=t.mono_ms
        return {mono_ms=t.mono_ms,utc_valid=t.utc_valid,utc_ms=t.utc_valid and t.utc_ms or nil}
    end
    local function expired(job,t)
        if t.mono_ms>=job.deadline_mono_ms then return "ttl" end
        if job.expires_utc_ms and t.utc_valid and t.utc_ms>=job.expires_utc_ms then return "utc" end
    end
    local function view(job)
        local v={id=job.id,owner=job.owner,resource=job.resource,media_id=job.media_id,
            media_revision=job.media_revision,source_id=job.source_id,state=job.state,
            accepted_mono_ms=job.accepted_mono_ms,deadline_mono_ms=job.deadline_mono_ms,
            expires_utc_ms=job.expires_utc_ms,reason=job.reason,exit_code=job.exit_code,signal=job.signal}
        return v
    end
    local function owned(owner,ticket)
        if not id(owner) or not int(ticket,1,MAX) then return nil,"request" end
        local job=jobs[ticket]
        if not job then return nil,"unknown" end
        if job.owner~=owner then return nil,"not_owner" end
        return job
    end
    function api.submit(owner,request)
        if busy then return err("busy") end
        if not id(owner) or not fields(request,{resource=true,media_id=true,media_revision=true,
            ttl_ms=true,expires_utc_ms=true,source_id=true}) or not resources[request.resource] or
            not id(request.media_id) or not id(request.media_revision) or not int(request.ttl_ms,1,MAX) or
            (request.expires_utc_ms~=nil and not int(request.expires_utc_ms,-MAX,MAX)) or
            (request.source_id~=nil and (type(request.source_id)~="string" or #request.source_id>256)) then
            return err("request")
        end
        local snapshot={}
        for k,v in pairs(request) do snapshot[k]=v end
        request=snapshot
        local resource=resources[request.resource]
        if records>=maximum or #resource.pending>=pending_max then return err("full") end
        if next_id==MAX then return err("id_exhausted") end
        busy=true; local t,why=now()
        if not t then busy=false;return err(why) end
        if request.ttl_ms>MAX-t.mono_ms then busy=false;return err("deadline_overflow") end
        next_id=next_id+1
        local job={id=next_id,owner=owner,resource=request.resource,media_id=request.media_id,
            media_revision=request.media_revision,source_id=request.source_id,
            accepted_mono_ms=t.mono_ms,deadline_mono_ms=t.mono_ms+request.ttl_ms,
            expires_utc_ms=request.expires_utc_ms,state="queued",media_lease=false,
            cleanup_target=false,cleanup_reason=false}
        -- Allocate the receipt and queue slots BEFORE acquiring a native lease.
        -- Only the final non-allocating assignments commit admission after pin.
        local receipt=view(job)
        job.state="admitting";jobs[job.id]=job;resource.pending[#resource.pending+1]=job
        busy=true
        if acquire then
            local ok,lease=pcall(acquire,media,job.media_id,job.media_revision)
            if not ok or type(lease)~="userdata" then
                jobs[job.id]=nil;resource.pending[#resource.pending]=nil;busy=false
                return err("media_unavailable")
            end
            job.media_lease=lease
        end
        job.state="queued";records=records+1;busy=false
        return receipt
    end
    function api.status(owner,ticket)
        local job,why=owned(owner,ticket); if not job then return err(why) end
        if job.state=="admitting" then return err("busy") end
        return view(job)
    end
    function api.cancel(owner,ticket)
        if busy then return err("busy") end
        local job,why=owned(owner,ticket); if not job then return err(why) end
        if job.state=="cancelled" then local v=view(job); v.changed=false; return v end
        if job.state~="queued" then return err(terminal[job.state] and "terminal" or "active") end
        busy=true;local released=release_media(job);busy=false
        if not released then
            job.state="finishing";job.cleanup_target="cancelled";job.cleanup_reason="owner_cancelled"
            return err("media_cleanup")
        end
        local q=resources[job.resource].pending
        for i,item in ipairs(q) do if item==job then table.remove(q,i); break end end
        job.state="cancelled"; job.reason="owner_cancelled"
        local v=view(job); v.changed=true; return v
    end
    -- Explicit receipt release ends status/cancel idempotency for this ID. IDs are never reused.
    function api.forget(owner,ticket)
        if busy then return err("busy") end
        local job,why=owned(owner,ticket); if not job then return err(why) end
        if not terminal[job.state] then return err("not_terminal") end
        jobs[ticket]=nil; records=records-1; return true
    end
    function api.step()
        if busy then return err("busy") end
        busy=true
        local output={events={},clock_error=nil}
        local function event(job,kind)
            local e=view(job); e.kind=kind; output.events[#output.events+1]=e
        end
        local function finish(resource,job,state,reason,exit_code,signal)
            if not release_media(job) then
                job.state="finishing";job.cleanup_target=state;job.cleanup_reason=reason
                return false
            end
            job.cleanup_target=false;job.cleanup_reason=false
            job.state=state; job.reason=reason; job.exit_code=exit_code; job.signal=signal
            if resource.active==job then resource.active=nil end
            event(job,state);return true
        end
        local function uncertain(job,reason)
            job.state="uncertain"; job.reason=reason
            if not job.fault_reported then job.fault_reported=true; event(job,"uncertain") end
        end
        for _,name in ipairs(order) do
            local resource=resources[name]
            local active=resource.active
            if active then
                local ok,result=pcall(poll,name,active.id)
                if ok and fields(result,{ticket=true,state=true,exit_code=true,signal=true,reason=true}) and result.ticket==active.id then
                    if result.state=="exited" and int(result.exit_code,0,255) and result.signal==nil and result.reason==nil then
                        finish(resource,active,result.exit_code==0 and "finished" or "failed","player_exit",result.exit_code)
                    elseif result.state=="running" and result.exit_code==nil and result.signal==nil and result.reason==nil then
                        active.state="playing"; active.reason=nil
                        if not active.started_reported then active.started_reported=true; event(active,"started") end
                    elseif (result.state=="launching" or result.state=="draining") and
                        result.exit_code==nil and result.signal==nil and result.reason==nil then
                        active.state=result.state=="launching" and "starting" or "finishing"; active.reason=nil
                    elseif result.state=="failed" and result.exit_code==nil and
                        ((result.reason=="player_signal" and int(result.signal,1,127)) or
                         (result.signal==nil and (result.reason=="player_not_started" or
                          result.reason=="player_exec_unknown" or result.reason=="player_begin_unknown"))) then
                        finish(resource,active,"failed",result.reason,nil,result.signal)
                    else uncertain(active,"poll_result") end
                else uncertain(active,"poll_unknown") end
            end
            -- Active completion is handled even if the clock fails; no slot is released on uncertainty.
            local t,why=now()
            if not t then output.clock_error=why else
                local waiting={}
                for _,job in ipairs(resource.pending) do
                    local reason=expired(job,t)
                    if job.cleanup_target then
                        if not finish(resource,job,job.cleanup_target,job.cleanup_reason) then waiting[#waiting+1]=job end
                    elseif reason then
                        if not finish(resource,job,"expired",reason) then waiting[#waiting+1]=job end
                    else waiting[#waiting+1]=job end
                end
                resource.pending=waiting
                local job=waiting[1]
                if not resource.active and job and job.state=="queued" and (not job.expires_utc_ms or t.utc_valid) then
                    local checking=true
                    local denial,backend_granted=nil,false
                    local function permit()
                        if not checking or resource.active~=job then return false,"stale" end
                        local fresh,problem=now()
                        if not fresh then denial=problem; return false,problem end
                        local reason=expired(job,fresh)
                        if reason then denial=reason; return false,reason end
                        if job.expires_utc_ms and not fresh.utc_valid then denial="utc_invalid"; return false,denial end
                        denial=nil; backend_granted=true; return true
                    end
                    table.remove(waiting,1); resource.active=job; job.state="starting"
                    local permitted=permit()
                    backend_granted=false -- start must call permit again immediately before its side effect.
                    local ok,result
                    if permitted then
                        ok,result=pcall(start,name,job.id,view(job),permit,job.media_lease or nil)
                    else ok=true; result={ticket=job.id,state="rejected"} end
                    checking=false
                    if ok and fields(result,{ticket=true,state=true}) and result.ticket==job.id then
                        if result.state=="started" and backend_granted and not denial then
                            job.state="playing"; job.started_reported=true; event(job,"started")
                        elseif result.state=="launching" and backend_granted and not denial then
                            job.state="starting"
                        elseif result.state=="deferred" and not backend_granted then
                            resource.active=nil; job.state="queued"; table.insert(waiting,1,job)
                        elseif result.state=="rejected" then
                            -- Rejected is a trusted guarantee that no player exists for this ticket.
                            if denial=="ttl" or denial=="utc" then finish(resource,job,"expired",denial)
                            elseif denial then
                                resource.active=nil; job.state="queued"; table.insert(waiting,1,job)
                                if denial~="utc_invalid" then output.clock_error=denial end
                            else finish(resource,job,"failed","player_rejected") end
                        else uncertain(job,"start_result") end
                    else uncertain(job,"start_unknown") end
                end
            end
        end
        busy=false; return output
    end
    return api
end
return M
