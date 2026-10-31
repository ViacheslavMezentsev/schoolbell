-- schoolbell TC-66/67: model only, no processes or native calls.
package.path="src/lua/?.lua;"..package.path
local C=require("schoolbell.player_codec")
local M=require("schoolbell.player_model")
local n=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();n=n+1;print("PASS player: "..name) end
local function err(code,value,e) eq(value,nil);eq(e.code,code) end
local function env()
    local e={time=0,reads={},wait_result="running",match=true,log={},forks=0,prepared=0,clean=0}
    local sys={}
    local function op(name,fn)
        sys[name]=function(...)
            e.log[#e.log+1]=name
            if e.throw==name then error(name) end
            return fn(...)
        end
    end
    op("random",function() return e.random or string.rep(string.char(92),16) end)
    op("open",function() return 10 end)
    op("flock",function() return true end)
    op("fcntl",function() return true end)
    op("pipe",function() return true end)
    op("dup",function() return true end)
    op("close",function() return true end)
    op("exec",function() return true end)
    op("write",function() return true end)
    op("exit",function() return true end)
    op("fstat",function() return {dev=1,ino=e.match and 2 or 3} end)
    op("fork",function() e.forks=e.forks+1; return e.pid==nil and 123 or e.pid,11 end)
    op("clock",function() return e.time end)
    op("read",function(_,size)
        eq(size,16)
        if #e.reads==0 then return nil,"again" end
        return table.remove(e.reads,1)
    end)
    op("open_exe",function() if e.no_exe then return nil end; return 20 end)
    op("wait",function() return e.wait_result,10 end)
    sys.valid_signal=function(v) return v==9 or v==128 end
    sys.prepare=function(call,token,media,resource)
        e.prepared=e.prepared+1
        call("open",media);call("flock",resource)
        token.open=true
        return {dev=1,ino=2}
    end
    sys.cleanup=function(call,token)
        e.clean=e.clean+1
        if token.open then call("close",10);token.open=false end
        return not e.hold_cleanup
    end
    e.sys=sys
    return e
end
local function new(e,opts) return assert(M.new(e.sys,opts or {resources={"speaker","other"}})) end
local function begin(q,resource,permit) return assert(q.begin({resource=resource or "speaker"},{},permit or function() return true end)) end
local function replace(s,pos,value) return s:sub(1,pos-1)..string.char(value)..s:sub(pos+1) end

test("exact golden frame, all valid stages and errno boundaries",function()
    local expected=string.char(83,66,80,69,1,1,0,8,0,0,0,2,0,0,0,0)
    eq(C.encode("exec",2),expected)
    for _,stage in ipairs({"stdio","exec","cleanup"}) do
        for _,v in ipairs({1,255,256,4095}) do
            local decoded=assert(C.decode(assert(C.encode(stage,v))))
            eq(decoded.stage,stage);eq(decoded.errno,v)
        end
    end
end)
test("every invalid byte position and lengths",function()
    local f=assert(C.encode("exec",2))
    for _,i in ipairs({1,2,3,4,5,6,7,9,10,13,14,15,16}) do
        eq(C.decode(replace(f,i,255)),nil)
    end
    for _,stage in ipairs({0,1,2,3,4,6,7,9,11,255}) do eq(C.decode(replace(f,8,stage)),nil) end
    eq(C.decode(replace(f,12,0)),nil)
    eq(C.decode(replace(f,11,16)),nil)
    eq(C.decode(f:sub(1,15)),nil);eq(C.decode(f.."x"),nil)
    eq(C.encode("fork",2),nil);eq(C.encode("exec",0/0),nil)
    eq(C.encode("exec","2"),nil);eq(C.encode("exec",1.5),nil)
end)
test("every split, bytewise frame, EOF and extra bytes",function()
    local f=assert(C.encode("exec",2))
    for cut=0,16 do
        local d=C.decoder()
        assert(d.feed(f:sub(1,cut),false))
        local v=assert(d.feed(f:sub(cut+1),true));eq(v.frame.errno,2);eq(v.eof,true)
        eq(d.feed("",true),nil)
    end
    local d=C.decoder()
    for i=1,16 do assert(d.feed(f:sub(i,i),false)) end
    eq(d.feed("x",false),nil);eq(d.feed("",true),nil)
    d=C.decoder();assert(d.feed("SBPE",false));eq(d.feed("",true),nil)
    eq(C.decoder().feed("",true).frame,nil)
end)
test("generation uses exactly 16 bytes including zero and newline",function()
    local e=env();e.random=string.char(0,10)..string.rep("A",14)
    local q=new(e);local h=begin(q);local s=q.poll(h)
    eq(s.generation,"000a"..string.rep("41",14))
    eq(s.attempt_id,1)
    s.error={code="forged"};s.state="forged";h.pid=999
    assert(q.poll(h).state~="forged")
end)
test("random failures never fall back",function()
    for _,value in ipairs({"","short",string.rep("x",17)}) do
        local e=env();e.random=value;eq(M.new(e.sys,{resources={"speaker"}}),nil);eq(e.forks,0)
    end
    local e=env();e.throw="random";eq(M.new(e.sys,{resources={"speaker"}}),nil)
end)
test("strict configuration bounds and defaults",function()
    for _,options in ipairs({{}, {resources={}}, {resources={[2]="speaker"}},
        {resources={"x","x"}},{resources={"x"},max_records=false},
        {resources={"x"},max_records=129},{resources={"x"},max_records=0},
        {resources={"x"},launch_timeout_ms=99},{resources={"x"},launch_timeout_ms=60001},
        {resources={"x"},launch_timeout_ms="2000"},{resources={"x"},launch_timeout_ms=0/0},
        {resources={"x"},unknown=true},{resources={"x","y","z","w","v"}}}) do
        eq(M.new(env().sys,options),nil)
    end
    for _,t in ipairs({100,60000}) do
        assert(M.new(env().sys,{resources={"a","b","c","d"},max_records=128,launch_timeout_ms=t}))
    end
    eq(M.new(env().sys,setmetatable({resources={"x"}},{})),nil)
end)
test("counter exhaustion and gaps never wrap",function()
    local c=assert(M.counter(4294967294))
    eq(c(),4294967295);err("limit",c());err("limit",c())
    eq(M.counter(-1),nil);eq(M.counter(0/0),nil)
    local e=env();local q=new(e)
    err("permit_denied",q.begin({resource="speaker"},{},function() return false end))
    eq(q.poll(begin(q)).attempt_id,2)
end)
test("launching then exec identity, no repeat observation",function()
    local e=env();local q=new(e);local h=begin(q)
    eq(e.forks,1);err("busy",q.begin({resource="speaker"},{},function() return true end))
    local s,_,stats=q.poll(h);eq(s.state,"running");eq(s.exec_status,"confirmed");assert(stats.calls<=8)
    e.log={};q.poll(h)
    for _,name in ipairs(e.log) do assert(name~="open_exe") end
    err("not_terminal",q.release(h))
end)
test("EOF and wrong executable never prove exec; timeout equality",function()
    local e=env();e.match=false;e.reads={""};local q=new(e);local h=begin(q)
    eq(q.poll(h).exec_status,"pending")
    e.no_exe=true;e.time=1999;eq(q.poll(h).state,"launching")
    e.time=2000;local s=q.poll(h);eq(s.state,"uncertain");eq(s.exec_status,"unknown");eq(s.launch_timeout,true)
    err("not_terminal",q.release(h));eq(e.forks,1)
    e.no_exe=false;e.match=true;s=q.poll(h);eq(s.exec_status,"confirmed");eq(s.launch_timeout,true)
end)
test("fast exit without observed exec retains independent outcome",function()
    local e=env();e.match=false;e.reads={""};e.wait_result={kind="exit",code=0}
    local q=new(e);local h=begin(q);local s=q.poll(h)
    eq(s.state,"terminal");eq(s.exec_status,"unknown");eq(s.outcome,"exit");eq(s.exit_code,0);eq(s.signal,nil)
    e.log={};q.poll(h)
    for _,name in ipairs(e.log) do assert(name~="open_exe" and name~="wait") end
    assert(q.release(h));err("stale_handle",q.poll(h))
end)
test("signals use platform predicate, never exit 128+signal",function()
    local e=env();e.match=false;e.reads={""};e.wait_result={kind="signal",signal=128}
    local q=new(e);local h=begin(q);local s=q.poll(h)
    eq(s.outcome,"signal");eq(s.signal,128);eq(s.exit_code,nil)
    assert(q.release(h))
    e=env();e.wait_result={kind="signal",signal=7};q=new(e);h=begin(q)
    eq(q.poll(h).state,"uncertain");err("not_terminal",q.release(h))
end)
test("exec frame followed by confirmed child exit is not_started",function()
    local e=env();e.reads={assert(C.encode("exec",2)),""};e.wait_result={kind="exit",code=127}
    local q=new(e);local h=begin(q);local s=q.poll(h)
    eq(s.exec_status,"failed");eq(s.outcome,"not_started");eq(s.error.code,"exec_failed");eq(s.error.errno,2)
    err("busy",q.release(h));q.poll(h);assert(q.release(h))
end)
test("frame can arrive across polls after reap without PID access",function()
    local e=env();e.match=false;local f=assert(C.encode("stdio",9))
    e.reads={f:sub(1,3),f:sub(4),""};e.wait_result={kind="exit",code=127}
    local q=new(e);local h=begin(q);q.poll(h);e.log={}
    local s=q.poll(h);eq(s.outcome,"not_started");eq(s.error.stage,"stdio")
    for _,name in ipairs(e.log) do assert(name~="wait" and name~="open_exe") end
    q.poll(h);assert(q.release(h))
end)
test("malformed or extra frame holds resource until exit",function()
    for _,chunks in ipairs({{"broken",""}, {assert(C.encode("exec",2)),"x"}}) do
        local e=env();e.reads=chunks;local q=new(e);local h=begin(q)
        q.poll(h);local s=q.poll(h);eq(s.error.code,"protocol_error")
        err("not_terminal",q.release(h))
        e.wait_result={kind="exit",code=1};q.poll(h);assert(q.release(h))
    end
end)
test("foreign handles rejected despite identical generations",function()
    local e=env();local a=new(e);local b=new(env());local h=begin(a)
    err("invalid_handle",b.poll(h));err("invalid_handle",a.poll({}))
end)
test("clock regression, invalid clock and overflow before fork",function()
    local e=env();e.time=9007199254740991;local q=new(e)
    err("limit",q.begin({resource="speaker"},{},function() return true end));eq(e.forks,0)
    e=env();e.time=0/0;q=new(e);err("clock_error",q.begin({resource="speaker"},{},function() return true end))
    e=env();local h;q=new(e);h=begin(q);e.time=5;q.poll(h);e.time=4
    eq(q.poll(h).error.code,"clock_error")
end)
test("fork rejection versus lost fork acknowledgement",function()
    local e=env();e.pid=false;local q=new(e)
    err("spawn_failed",q.begin({resource="speaker"},{},function() return true end))
    e=env();e.throw="fork";q=new(e);local h=begin(q)
    eq(q.poll(h).state,"uncertain");err("not_terminal",q.release(h))
    err("busy",q.begin({resource="speaker"},{},function() return true end))
end)
test("record quotas include terminal receipts",function()
    local e=env();local q=new(e,{resources={"speaker","other"},max_records=1})
    local h=begin(q);e.reads={""};e.wait_result={kind="exit",code=0};q.poll(h)
    err("limit",q.begin({resource="other"},{},function() return true end))
    assert(q.release(h));begin(q,"other")
end)
test("cleanup failure is retained and retried explicitly",function()
    local e=env();local q=new(e);local h=begin(q)
    e.reads={""};e.wait_result={kind="exit",code=0};q.poll(h);e.hold_cleanup=true
    err("cleanup_failed",q.release(h));eq(q.poll(h).cleanup_pending,true)
    err("busy",q.begin({resource="speaker"},{},function() return true end))
    e.hold_cleanup=false;assert(q.release(h))
end)
test("failure before fork with pending cleanup returns a handle",function()
    local e=env();e.hold_cleanup=true;local q=new(e)
    local h=begin(q,nil,function() return false end)
    local s=q.poll(h);eq(s.outcome,"not_started");eq(e.forks,0)
    e.hold_cleanup=false;assert(q.release(h))
end)
test("preparation budget reserves clock and fork",function()
    local e=env()
    e.sys.prepare=function(call)
        for _=1,63 do call("open") end
        return {dev=1,ino=2}
    end
    local q=new(e);err("limit",q.begin({resource="speaker"},{},function() return true end));eq(e.forks,0)
    e=env();e.sys.prepare=function(call)
        for _=1,62 do call("open") end
        return {dev=1,ino=2}
    end
    q=new(e);begin(q);eq(e.forks,1)
end)
test("child budget sealed and counted including failures",function()
    local e=env();local saved
    local result=M.child_setup(e.sys,function(call)
        saved=call
        for _=1,65 do call("close") end
        return true
    end,{})
    eq(result.ok,false);eq(result.calls,64);eq(result.exhausted,true)
    eq(pcall(saved,"close"),false)
    e.throw="close";result=M.child_setup(e.sys,function(call) call("close");return true end,{})
    eq(result.ok,false);eq(result.calls,1)
end)
test("cleanup stops at eight calls per pass",function()
    local e=env();e.sys.cleanup=function(call,token)
        token.left=token.left or 9
        while token.left>0 do call("close");token.left=token.left-1 end
        return true
    end
    local q=new(e);local h=begin(q);e.reads={""};e.wait_result={kind="exit",code=0};q.poll(h)
    local ok,why,stats=q.release(h);eq(ok,nil);eq(why.code,"cleanup_failed");eq(stats.calls,8)
    ok,why,stats=q.release(h);eq(ok,true);eq(stats.calls,1)
end)
test("one read per poll, total budget, faults do not escape",function()
    for _,name in ipairs({"clock","read","open_exe","fstat","wait"}) do
        local e=env();local q=new(e);local h=begin(q);e.log={};e.throw=name
        local s,_,stats=q.poll(h);assert(s);assert(stats.calls<=8)
        local reads=0;for _,op in ipairs(e.log) do if op=="read" then reads=reads+1 end end
        assert(reads<=1)
    end
end)
test("bad observation prevents later PID probing",function()
    local e=env();e.wait_result=nil;local q=new(e);local h=begin(q)
    eq(q.poll(h).state,"uncertain");e.log={};q.poll(h)
    for _,name in ipairs(e.log) do assert(name~="open_exe") end
end)
test("request/config copies, strict request and reentrancy",function()
    local e=env();local opts={resources={"speaker"}};local q=new(e,opts);opts.resources[1]="other"
    err("invalid_argument",q.begin({resource="speaker",executable="evil"},{},function() return true end))
    local h=begin(q,nil,function()
        err("busy",q.begin({resource="speaker"},{},function() return true end))
        return true
    end)
    e.sys.wait=function() error("replacement") end
    eq(q.poll(h).state,"running")
end)

test("extra bytes invalidate a previously decoded failure frame",function()
    local e=env();e.reads={assert(C.encode("exec",2)),"x"};local q=new(e);local h=begin(q)
    q.poll(h);q.poll(h);e.wait_result={kind="exit",code=127}
    local s=q.poll(h);eq(s.outcome,"exit");eq(s.exec_status,"unknown")
    eq(s.error.code,"protocol_error")
end)
test("failure frame contradicting observed executable is protocol error",function()
    local e=env();local q=new(e);local h=begin(q);q.poll(h)
    e.reads={assert(C.encode("exec",2))};local s=q.poll(h)
    eq(s.error.code,"protocol_error");eq(s.state,"uncertain");eq(s.exec_status,"confirmed")
end)
test("caught budget exception cannot authorize fork or child success",function()
    local e=env();e.sys.prepare=function(call)
        for _=1,70 do pcall(call,"open") end
        return {dev=1,ino=2}
    end
    local q=new(e);err("limit",q.begin({resource="speaker"},{},function() return true end))
    eq(e.forks,0)
    local result=M.child_setup(e.sys,function(call)
        for _=1,70 do pcall(call,"close") end
        return true
    end,{})
    eq(result.ok,false);eq(result.calls,64)
end)
test("failed begin cleanup stays within parent budget",function()
    local e=env();e.sys.prepare=function(call,token)
        for _=1,62 do call("open") end
        token.left=10
        return {dev=1,ino=2}
    end
    e.sys.cleanup=function(call,token)
        while token.left>0 do call("close");token.left=token.left-1 end
        return true
    end
    local q=new(e);e.log={}
    local h=begin(q,nil,function() return false end)
    eq(#e.log,64);eq(e.forks,0)
    local ok,_,stats=q.release(h);eq(ok,nil);eq(stats.calls,8)
    assert(q.release(h))
end)

test("final snapshot is stable and consumes no further system calls",function()
    local e=env();e.reads={""};e.wait_result={kind="exit",code=0}
    local q=new(e);local h=begin(q);local s=q.poll(h)
    e.throw="clock";local again,_,stats=q.poll(h)
    eq(again.state,s.state);eq(again.outcome,s.outcome);eq(stats.calls,0)
end)
test("fake cleanup cannot hide exhausted budget",function()
    local e=env();e.sys.cleanup=function(call)
        for _=1,9 do pcall(call,"close") end
        return true
    end
    local q=new(e);local h=begin(q);e.reads={""};e.wait_result={kind="exit",code=0};q.poll(h)
    err("cleanup_failed",q.release(h))
end)
print("PASS player codec/model: "..n.." groups")
