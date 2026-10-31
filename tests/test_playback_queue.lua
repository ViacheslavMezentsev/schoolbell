-- schoolbell TC-40/41/42: isolated queue, deadlines, cancellation and backend faults.
package.path="src/lua/?.lua;"..package.path
local Q=require("schoolbell.playback_queue")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn)
    fn(); count=count+1; print("PASS playback: "..name)
end
local function error_is(code,value,e) eq(value,nil); eq(e.code,code) end
local function env(options)
    local e={mono=0,utc=1000,valid=true,starts={},exits={}}
    e.clock=function()
        if e.bad then error("clock unavailable") end
        return {mono_ms=e.mono,utc_valid=e.valid,utc_ms=e.utc}
    end
    e.player={
        start=function(resource,ticket,request,permit)
            local allowed=permit()
            if not allowed then return {ticket=ticket,state="rejected"} end
            e.starts[#e.starts+1]={resource=resource,ticket=ticket,request=request}
            return {ticket=ticket,state="started"}
        end,
        poll=function(_,ticket)
            if e.exits[ticket] then return {ticket=ticket,state="exited",exit_code=e.exits[ticket]} end
            return {ticket=ticket,state="running"}
        end
    }
    e.options=options or {resources={"speaker","other"}}
    return e
end
local function worker(e) return assert(Q.new(e.clock,e.player,e.options)) end
local function request(ttl,utc,resource)
    return {resource=resource or "speaker",media_id="bell",media_revision="v1",
        ttl_ms=ttl or 100,expires_utc_ms=utc,source_id="calendar-1"}
end
local function submit(q,ttl,utc,resource) return assert(q.submit("schoolbell",request(ttl,utc,resource))).id end
local function state(q,id) return assert(q.status("schoolbell",id)).state end

test("admission has no side effect; FIFO and independent resources",function()
    local e=env(); local q=worker(e)
    local a,b,c=submit(q),submit(q),submit(q,nil,nil,"other")
    eq(#e.starts,0); q.step(); eq(#e.starts,2)
    eq(e.starts[1].ticket,a); eq(e.starts[2].ticket,c); eq(state(q,b),"queued")
    e.exits[a]=0; local out=q.step()
    eq(e.starts[3].ticket,b); eq(out.events[1].kind,"finished")
    eq(state(q,a),"finished"); eq(state(q,b),"playing")
end)
test("TTL equality and expired tail do not block survivors",function()
    local e=env(); local q=worker(e)
    local a,b,c=submit(q,10),submit(q,100),submit(q,10)
    e.mono=10; q.step()
    eq(state(q,a),"expired"); eq(state(q,c),"expired")
    eq(e.starts[1].ticket,b); eq(#e.starts,1)
end)
test("UTC equality expires, backward UTC cannot extend TTL",function()
    local e=env(); local q=worker(e); local a=submit(q,10,1000)
    q.step(); eq(state(q,a),"expired"); eq(#e.starts,0)
    local b=submit(q,10,2000); e.utc=-1000; e.mono=10
    q.step(); eq(state(q,b),"expired")
end)
test("invalid UTC preserves FIFO but not expired reservations",function()
    local e=env(); e.valid=false; local q=worker(e)
    local a,b,c=submit(q,10,2000),submit(q),submit(q,nil,nil,"other")
    q.step(); eq(state(q,a),"queued"); eq(state(q,b),"queued"); eq(state(q,c),"playing")
    e.mono=10; q.step(); eq(state(q,a),"expired"); eq(state(q,b),"playing")
end)
test("UTC recovery starts original FIFO head",function()
    local e=env(); e.valid=false; local q=worker(e); local a=submit(q,100,2000)
    q.step(); eq(#e.starts,0); e.valid=true; q.step(); eq(e.starts[1].ticket,a)
end)
test("owner checks, pending cancellation and explicit receipt release",function()
    local e=env(); local q=worker(e); local a,b=submit(q),submit(q)
    error_is("not_owner",q.cancel("other",a))
    error_is("not_owner",q.status("other",a))
    eq(q.cancel("schoolbell",a).changed,true); eq(q.cancel("schoolbell",a).changed,false)
    q.step(); eq(e.starts[1].ticket,b)
    error_is("active",q.cancel("schoolbell",b))
    error_is("not_terminal",q.forget("schoolbell",b))
    error_is("not_owner",q.forget("other",a))
    assert(q.forget("schoolbell",a)); error_is("unknown",q.cancel("schoolbell",a))
    assert(submit(q)>b)
end)
test("active expiry never stops playback; completion exactly once",function()
    local e=env(); local q=worker(e); local a=submit(q,1,1001)
    q.step(); e.mono=100; e.utc=5000; eq(#q.step().events,0); eq(state(q,a),"playing")
    e.exits[a]=7; local out=q.step(); eq(out.events[1].kind,"failed")
    eq(out.events[1].exit_code,7); eq(#q.step().events,0)
    error_is("terminal",q.cancel("schoolbell",a))
end)
test("explicit no-process rejection releases slot next step",function()
    local e=env(); e.player.start=function(_,id) return {ticket=id,state="rejected"} end
    local q=worker(e); local a,b=submit(q),submit(q)
    eq(#q.step().events,1); eq(state(q,a),"failed"); eq(state(q,b),"queued")
    q.step(); eq(state(q,b),"failed")
end)
test("possible launch followed by exception holds resource",function()
    local e=env(); e.player.start=function(_,id,_,permit)
        assert(permit()); e.launched=id; error("lost acknowledgement")
    end
    local q=worker(e); local a,b=submit(q),submit(q)
    q.step(); eq(e.launched,a); eq(state(q,a),"uncertain"); eq(state(q,b),"queued")
    error_is("active",q.cancel("schoolbell",a))
    q.step(); eq(state(q,a),"playing"); eq(state(q,b),"queued")
    e.exits[a]=0; q.step(); eq(e.launched,b)
end)
test("stale/malformed poll never releases active slot",function()
    local e=env(); local reply; e.player.poll=function() return reply end
    local q=worker(e); local a,b=submit(q),submit(q); q.step()
    reply={ticket=a+1,state="exited",exit_code=0}
    eq(#q.step().events,1); eq(state(q,a),"uncertain"); eq(state(q,b),"queued")
    reply={ticket=a,state="exited",exit_code=-1}; eq(#q.step().events,0)
    reply={ticket=a,state="exited",exit_code=0}; q.step(); eq(state(q,b),"playing")
end)
test("throwing poll is contained and does not flood events",function()
    local e=env(); e.player.poll=function() error("poll") end
    local q=worker(e); local a=submit(q); q.step()
    eq(#q.step().events,1); for _=1,100 do eq(#q.step().events,0) end
    eq(state(q,a),"uncertain")
end)
test("deadline rechecked at backend side effect",function()
    for _,which in ipairs({"mono","utc"}) do
        local e=env(); local saved
        e.player.start=function(_,id,_,permit)
            saved=permit
            if which=="mono" then e.mono=10 else e.utc=1010 end
            local allowed=permit(); eq(allowed,false)
            return {ticket=id,state="rejected"}
        end
        local q=worker(e); local a=submit(q,10,1010)
        q.step(); eq(state(q,a),"expired"); eq(saved(),false)
    end
end)
test("UTC loss during launch restores head with original TTL",function()
    local e=env(); e.player.start=function(_,id,_,permit)
        e.valid=false; eq(permit(),false); return {ticket=id,state="rejected"}
    end
    local q=worker(e); local a,b=submit(q,10,2000),submit(q)
    q.step(); eq(state(q,a),"queued"); eq(state(q,b),"queued")
    e.mono=10; q.step(); eq(state(q,a),"expired")
end)
test("clock failure during launch retains pending work",function()
    local e=env(); e.player.start=function(_,id,_,permit)
        e.bad=true; eq(permit(),false); return {ticket=id,state="rejected"}
    end
    local q=worker(e); local a=submit(q)
    eq(q.step().clock_error,"clock"); eq(state(q,a),"queued")
    e.bad=false; e.mono=100; q.step(); eq(state(q,a),"expired")
end)
test("started without permit is uncertain, not success",function()
    local e=env(); e.player.start=function(_,id) return {ticket=id,state="started"} end
    local q=worker(e); local a,b=submit(q),submit(q)
    q.step(); eq(state(q,a),"uncertain"); eq(state(q,b),"queued")
end)
test("malformed start result is uncertain",function()
    for _,result in ipairs({false,{}, {ticket=1,state="started",extra=true},
        setmetatable({ticket=1,state="rejected"},{})}) do
        local e=env(); e.player.start=function() return result end
        local q=worker(e); local a=submit(q); q.step(); eq(state(q,a),"uncertain")
    end
end)
test("clock faults prevent new starts but allow confirmed completion",function()
    local e=env(); local q=worker(e); local a,b=submit(q),submit(q); q.step()
    e.exits[a]=0; e.bad=true
    eq(q.step().clock_error,"clock"); eq(state(q,a),"finished"); eq(state(q,b),"queued")
    error_is("clock",q.submit("schoolbell",request()))
    e.bad=false; e.mono=5; q.step(); e.mono=4
    eq(q.step().clock_error,"clock_regressed")
    error_is("clock_regressed",q.submit("schoolbell",request()))
end)
test("malformed clock and deadline overflow rejected",function()
    for _,t in ipairs({{}, {mono_ms=0,utc_valid=1},{mono_ms=0/0,utc_valid=false},
        {mono_ms=0,utc_valid=true}, {mono_ms=math.huge,utc_valid=false}}) do
        local e=env(); local q=assert(Q.new(function() return t end,e.player,e.options))
        error_is("clock",q.submit("schoolbell",request()))
    end
    local e=env(); e.mono=9007199254740991; local q=worker(e)
    error_is("deadline_overflow",q.submit("schoolbell",request(1)))
end)
test("bounded pending and retained receipts, explicit forget",function()
    local e=env({resources={"speaker"},max_records=2,max_pending=1}); local q=worker(e)
    local a=submit(q); error_is("full",q.submit("schoolbell",request()))
    q.step(); local b=submit(q); q.cancel("schoolbell",b)
    error_is("full",q.submit("schoolbell",request()))
    q.forget("schoolbell",b); local c=submit(q); assert(c>b)
    e.exits[a]=0; q.step(); eq(state(q,c),"playing")
end)
test("input/output snapshots and frozen configuration",function()
    local e=env(); local q=worker(e); local r=request(); local a=q.submit("schoolbell",r)
    r.media_id="changed"; a.state="cancelled"; e.options.resources[1]="changed"
    e.player.start=function() error("mutated") end
    q.step(); eq(e.starts[1].request.media_id,"bell")
    e.starts[1].request.state="cancelled"
    eq(state(q,a.id),"playing"); local v=q.status("schoolbell",a.id); v.state="bad"
    eq(state(q,a.id),"playing")
end)
test("reentrant mutation rejected from clock and player",function()
    local e=env(); local q
    local base=e.clock
    e.clock=function()
        if q then error_is("busy",q.submit("schoolbell",request())); error_is("busy",q.step()) end
        return base()
    end
    e.player.start=function(_,id,_,permit)
        error_is("busy",q.cancel("schoolbell",id))
        error_is("busy",q.forget("schoolbell",id))
        eq(q.status("schoolbell",id).state,"starting")
        assert(permit()); return {ticket=id,state="started"}
    end
    q=worker(e); local a=submit(q); q.step(); eq(state(q,a),"playing")
end)
test("strict configuration and request validation",function()
    local e=env()
    for _,o in ipairs({{}, {resources={}}, {resources={"x","x"}}, {resources={[2]="x"}},
        {resources={"x"},max_records=false}, {resources={"x"},max_pending=0},
        {resources={"x"},max_records=129}, {resources={"a","b","c","d","e"}},
        {resources={"x"},unknown=1}, setmetatable({resources={"x"}},{})}) do
        eq(Q.new(e.clock,e.player,o),nil)
    end
    local q=worker(e)
    for _,patch in ipairs({{ttl_ms=0},{ttl_ms=-1},{ttl_ms=0.5},{ttl_ms=math.huge},
        {ttl_ms=0/0},{resource="missing"},{media_id="../bell"},{media_revision=false},
        {source_id=string.rep("a",257)},{expires_utc_ms=false},{unknown=1}}) do
        local r=request(); for k,v in pairs(patch) do r[k]=v end
        error_is("request",q.submit("schoolbell",r))
    end
    error_is("request",q.submit("schoolbell",setmetatable(request(),{})))
    error_is("request",q.submit("",request()))
    eq(Q.new(e.clock,{},e.options),nil)
end)

test("admission snapshots request before clock callback",function()
    local e=env(); local r=request(); local clock=e.clock
    e.clock=function() r.ttl_ms=-1; r.resource="missing"; return clock() end
    local q=worker(e); local a=assert(q.submit("schoolbell",r))
    eq(a.resource,"speaker"); eq(a.deadline_mono_ms,100)
end)
test("21 simultaneous requests drain in FIFO with bounded player calls",function()
    local e=env(); local q=worker(e); local ids={}
    for i=1,21 do ids[i]=submit(q) end
    for i=1,21 do
        local before=#e.starts; q.step(); eq(#e.starts,before+1)
        eq(e.starts[i].ticket,ids[i]); e.exits[ids[i]]=0
    end
    q.step(); eq(#e.starts,21)
    for _,id in ipairs(ids) do eq(state(q,id),"finished") end
end)
print("PASS schoolbell playback queue: "..count.." groups")
