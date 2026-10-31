-- schoolbell TC-70: native Lua ownership, result contract and real fixture child.
local native=require("schoolbell.player_linux")
local groups=0
local function pass(s) groups=groups+1; print("PASS Lua Linux player: "..s) end
local function options(mode)
  return {executable_fd=executable_fd, lock_directory_fd=directory_fd,
    argv={"fixture",mode or "ok"},resources={"speaker","second"},
    launch_timeout_ms=2000,max_records=4}
end
local function create(mode) return assert(native.new(options(mode))) end
local function denied(value,err,code) assert(value==nil and err.code==code,err and err.code) end
local function start(p,resource)
  local h,e,stats=p:begin({resource=resource or "speaker"},media_fd,function() return true end)
  assert(h and not e and type(h)=="userdata" and stats.calls<=64)
  return h
end
local function finish(p,h)
  for _=1,600 do
    local s,e,stats=p:poll(h);assert(s and not e and stats.calls<=8)
    if s.state=="terminal" then
      local ok,err,c=p:release(h)
      if ok then assert(c.calls<=8);return s end
      assert(err.code=="busy")
    end
    pause()
  end
  error("fixture timeout")
end
local initial=fd_count()
for _,mode in ipairs({"ok","exit7","signal","flood"}) do
  local p=create(mode);local h=start(p);local s=finish(p,h)
  assert(#s.generation==32 and s.generation:match("^[0-9a-f]+$") and s.attempt_id==1)
  assert(type(s.launch_timeout)=="boolean" and type(s.cleanup_pending)=="boolean")
  if mode=="signal" then assert(s.outcome=="signal" and s.signal==15 and s.exit_code==nil)
  else assert(s.outcome=="exit" and s.exit_code==(mode=="exit7" and 7 or 0) and s.signal==nil) end
  assert(s.error==nil);assert(p:close())
end
pass("actual exec/exit/signal/flood; optional fields and call budgets")

do
  local p=create("hold");local h=start(p)
  local a,e=p:release(h);denied(a,e,"not_terminal")
  a,e=p:close();denied(a,e,"busy");assert(e.errno==nil)
  a,e=p:begin({resource="speaker"},media_fd,function() return true end);denied(a,e,"busy")
  local q=create();a,e=q:poll(h);denied(a,e,"invalid_handle");assert(q:close())
  local second=start(p,"second")
  local s
  for _=1,100 do s=assert(p:poll(h));if s.exec_status=="confirmed" then break end;pause() end
  assert(s.exec_status=="confirmed" and s.state=="running" and s.outcome==nil)
  s.state="terminal";s.generation="forged"
  assert(p:poll(h).generation~="forged")
  finish(p,h);finish(p,second)
  a,e=p:poll(h);denied(a,e,"stale_handle")
  a,e=p:release(h);denied(a,e,"stale_handle")
  assert(p:close())
  a,e=p:pending();denied(a,e,"invalid_handle")
end
pass("opaque foreign/stale handles; snapshots copied; busy resource and close")

do
  local p=create()
  for _,permit in ipairs({function() return false end,function() error("failure") end,function() return 1 end}) do
    local a,e=p:begin({resource="speaker"},media_fd,permit);denied(a,e,"permit_denied")
    assert(e.stage=="permit" and e.errno==nil and #p:pending()==0)
  end
  local h=assert(p:begin({resource="speaker"},media_fd,function()
    local a,e=p:close();denied(a,e,"busy");assert(e.errno==nil)
    a,e=p:pending();denied(a,e,"busy")
    a,e=p:begin({resource="speaker"},media_fd,function() return true end);denied(a,e,"busy")
    collectgarbage("collect")
    return true
  end))
  finish(p,h);assert(p:close())
end
pass("protected permit exceptions/strict boolean/reentrancy/GC before fork")

do
  local p=create("hold");local h=start(p);local weak=setmetatable({h},{__mode="v"})
  h=nil;collectgarbage("collect");assert(weak[1])
  local pending=p:pending();assert(#pending==1 and pending[1]==weak[1])
  finish(p,pending[1]);pending=nil;collectgarbage("collect");assert(weak[1]==nil)
  assert(#p:pending()==0 and p:close())
  local retained=create("hold");local live=start(retained)
  local owner_weak=setmetatable({retained},{__mode="v"});retained=nil
  collectgarbage("collect");assert(owner_weak[1])
  finish(owner_weak[1],live);assert(owner_weak[1]:close());live=nil
  collectgarbage("collect");assert(owner_weak[1]==nil)
  local empty=create();empty=nil;collectgarbage("collect")
  assert(fd_count()==initial)
end
pass("discarded handle recoverable via pending; explicit release drops GC pin")

do
  local p=create("hold")
  local ok=pcall(function()
    p:begin({resource="speaker"},media_fd,function() fail_allocations();return true end)
  end)
  allow_allocations()
  assert(not ok,"expected Lua allocation failure after permit")
  local pending=p:pending();assert(#pending==1,"lost ownership after OOM")
  local result=finish(p,pending[1]);assert(result.outcome=="exit" and result.exit_code==0);assert(p:close())
end
pass("allocation failure after fork retains recoverable handle and native ownership")

do
  local o=options();o.executable_fd=broken_fd;local p=assert(native.new(o))
  local h=start(p);local s=finish(p,h)
  assert(s.outcome=="not_started" and s.exec_status=="failed")
  assert(s.error.code=="exec_failed" and s.error.stage=="exec" and s.error.errno>0)
  assert(s.exit_code==nil and s.signal==nil);assert(p:close())
end
pass("exec failure mapped to structured error without fabricated exit")

do
  for _,change in ipairs({
    function(o)o.extra=true end,
    function(o)o.max_records=0 end,
    function(o)o.launch_timeout_ms=0/0 end,
    function(o)o.executable_fd="3" end,
    function(o)o.resources={"a", "a"} end,
    function(o)o.resources={[1]="a",[3]="c"} end,
    function(o)o.argv={"fixture","ok\0bad"} end,
    function(o)setmetatable(o,{__index=function() error("must not execute") end}) end
  }) do
    local o=options();change(o);local p,e=native.new(o);assert(not p and e)
  end
  local p=create()
  local a,e=p:poll({});denied(a,e,"invalid_handle")
  a,e=p:begin({resource="speaker",extra=true},media_fd,function()return true end);denied(a,e,"invalid_argument")
  a,e=p:begin({resource="speaker"},directory_fd,function()return true end);denied(a,e,"media_invalid")
  assert(p:close())
  local o=options();o.max_records=1;local q=assert(native.new(o));local h=start(q)
  a,e=q:begin({resource="second"},media_fd,function()return true end);denied(a,e,"limit")
  finish(q,h);assert(q:close())
end
pass("strict options and requests; no metamethods/coercion/NUL; capacity bound")
for _=1,12 do local p=create();local h=start(p);finish(p,h);assert(p:close()) end
collectgarbage("collect");assert(fd_count()==initial)
pass("repeated Lua lifecycle has no FD leak or unreaped child")
assert(groups==8);print("PASS Lua Linux player: 8 groups; no audio/core/router")
