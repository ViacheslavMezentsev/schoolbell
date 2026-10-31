-- Isolated queue/backend composition. No core, device paths or media manager.
local M={}
local function plain(t) return type(t)=="table" and getmetatable(t)==nil end
local function id(s) return type(s)=="string" and #s>0 and #s<=64 and s:match("^[A-Za-z0-9_-]+$") end
local function fail(code) return nil,{code=code} end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end
function M.new(native,resolve,resources)
    if (type(native)~="userdata" and not plain(native)) or type(resolve)~="function" or not plain(resources) then return fail("backend") end
    local begin,poll,release,pending,close=native.begin,native.poll,native.release,native.pending,native.close
    if type(begin)~="function" or type(poll)~="function" or type(release)~="function" or type(pending)~="function" or type(close)~="function" then return fail("backend") end
    local slots,order={},{}
    local count=0
    for k in pairs(resources) do
        count=count+1
        if type(k)~="number" or k%1~=0 or k<1 or k>4 then return fail("resources") end
    end
    if count<1 or count>4 then return fail("resources") end
    for i=1,count do
        local name=resources[i]
        if not id(name) or slots[name]~=nil then return fail("resources") end
        order[i]=name;slots[name]=false
    end
    local ok,existing=pcall(pending,native)
    if not ok or not plain(existing) or next(existing) then return fail("busy") end
    local busy,closed,orphan=false,false,false
    local api={}
    local function response(r,state) return {ticket=r.ticket,state=state} end
    local function recover(r)
        local good,list=pcall(pending,native)
        if not good or not plain(list) then return false end
        local candidate,n=nil,0
        for _,h in pairs(list) do
            local known=false
            for _,name in ipairs(order) do
                local other=slots[name]
                if other and other~=r and other.handle==h then known=true end
            end
            if not known then candidate=h;n=n+1 end
        end
        if n>1 then return false end
        if not candidate then r.final={ticket=r.ticket,state="failed",reason="player_begin_unknown"} end
        r.handle=candidate or false;r.unknown=false;orphan=false
        return true
    end
    local function start(resource,ticket,request,permit,media_lease)
        if closed or slots[resource]==nil then error("closed or unknown resource") end
        local old=slots[resource]
        if old and not old.final then return {ticket=ticket,state="uncertain"} end
        -- A lost begin result can own one unclaimed handle. Do not launch a
        -- second ambiguous attempt until it has been reconciled.
        if orphan then return {ticket=ticket,state="deferred"} end
        local r={ticket=ticket,handle=false,final=false,snapshot=false,
            release_unknown=false,unknown=false,media_lease=media_lease}
        slots[resource]=r -- reserve bookkeeping before any possible child
        r.unknown=true;orphan=r
        local good,fd
        if media_lease then good,fd=pcall(media_lease.fd,media_lease)
        else good,fd=pcall(resolve,request.media_id,request.media_revision) end
        if not good or type(fd)~="number" or fd%1~=0 or fd<0 or fd>2147483647 then
            r.final=response(r,"rejected");r.unknown=false;orphan=false;return copy(r.final)
        end
        -- Native permit is invoked after its own preparation, immediately before fork.
        local called,h=pcall(begin,native,{resource=resource},fd,permit,media_lease)
        if not called then
            r.unknown=true;orphan=r
            return response(r,"uncertain")
        end
        if not h then r.final=response(r,"rejected");r.unknown=false;orphan=false;return copy(r.final) end
        r.handle=h;r.unknown=false;orphan=false
        return response(r,"launching")
    end
    local function terminal(r,s)
        local result={ticket=r.ticket}
        if s.outcome=="signal" then
            result.state="failed";result.reason="player_signal";result.signal=s.signal
        elseif s.outcome=="not_started" then
            result.state="failed";result.reason="player_not_started"
        elseif s.outcome=="exit" and s.exec_status=="confirmed" and not s.error then
            result.state="exited";result.exit_code=s.exit_code
        else result.state="failed";result.reason="player_exec_unknown" end
        return result
    end
    local function cleanup(r)
        -- Build the retained result before releasing the native record.
        if not r.release_unknown then r.result=terminal(r,r.snapshot) end
        local good,released,why=pcall(release,native,r.handle)
        if good and (released or (r.release_unknown and type(why)=="table" and why.code=="stale_handle")) then
            r.final=r.result;r.handle=false;r.release_unknown=false
            return copy(r.final)
        end
        r.release_unknown=not good
        return response(r,"draining")
    end
    local function observe(resource,ticket)
        local r=slots[resource]
        if closed or not r or r.ticket~=ticket then error("unknown ticket") end
        if r.final then return copy(r.final) end
        if r.unknown then
            if not recover(r) then return response(r,"uncertain") end
            if r.final then return copy(r.final) end
        end
        if r.release_unknown then return cleanup(r) end
        local good,s=pcall(poll,native,r.handle)
        if not good or not plain(s) then return response(r,"uncertain") end
        if s.state=="terminal" then r.snapshot=s;return cleanup(r) end
        if s.state=="running" and s.exec_status=="confirmed" then return response(r,"running") end
        if s.state=="launching" then return response(r,"launching") end
        return response(r,"uncertain")
    end
    local function guarded(fn,...)
        if busy then error("reentrant backend") end
        busy=true
        local ok,value=pcall(fn,...)
        busy=false
        if not ok then error(value,0) end
        return value
    end
    function api.start(...) return guarded(start,...) end
    function api.poll(...) return guarded(observe,...) end
    function api.close()
        if busy then return fail("busy") end
        if closed then return fail("closed") end
        for _,name in ipairs(order) do
            if slots[name] and not slots[name].final then return fail("busy") end
        end
        local good,value=pcall(close,native)
        if not good or not value then return fail("busy") end
        closed=true;return true
    end
    return api
end
return M
