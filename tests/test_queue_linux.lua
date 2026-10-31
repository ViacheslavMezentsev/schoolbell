-- schoolbell TC-71: queue + real Linux binding, no audio/core/router.
package.path="src/lua/?.lua;"..package.path
local Native=require("schoolbell.player_linux")
local Queue=require("schoolbell.playback_queue")
local Bridge=require("schoolbell.queue_player")
local groups=0
local function pass(s) groups=groups+1;print("PASS queue Linux: "..s) end
local function setup(mode,wrap,resolve)
  local p=assert(Native.new({executable_fd=mode=="bad" and broken_fd or executable_fd,
    lock_directory_fd=directory_fd,argv={"fixture",mode or "hold"},
    resources={"speaker","other"},max_records=4}))
  local e={time=0,utc=1000,valid=true,events={},resolved=0,native=p}
  e.clock=function() if e.bad_clock then error("clock") end;return {mono_ms=e.time,utc_valid=e.valid,utc_ms=e.utc} end
  local driver=wrap and wrap(p,e) or p
  e.backend=assert(Bridge.new(driver,function(id,revision)
    e.resolved=e.resolved+1
    if resolve then return resolve(e,id,revision) end
    assert(id=="bell" and revision=="v1");return media_fd
  end,{"speaker","other"}))
  e.worker=assert(Queue.new(e.clock,e.backend,{resources={"speaker","other"}}))
  return e
end
local function submit(e,resource,ttl,utc)
  return assert(e.worker.submit("owner",{resource=resource or "speaker",media_id="bell",
    media_revision="v1",ttl_ms=ttl or 5000,expires_utc_ms=utc})).id
end
local function status(e,ticket)return assert(e.worker.status("owner",ticket)) end
local function step(e)
  local result=assert(e.worker.step())
  for _,v in ipairs(result.events) do e.events[#e.events+1]=v end
  return result
end
local function wait(e,tickets)
  for _=1,600 do
    step(e);local done=true
    for _,ticket in ipairs(tickets) do
      local s=status(e,ticket).state
      if s~="finished" and s~="failed" and s~="cancelled" and s~="expired" then done=false end
    end
    if done then return end;pause()
  end
  error("host queue timeout")
end
local function wrapper(p)
  return {begin=function(_,...)return p:begin(...)end,poll=function(_,...)return p:poll(...)end,
    release=function(_,...)return p:release(...)end,pending=function()return p:pending()end,
    close=function()return p:close()end}
end
local function end_test(e)assert(#e.native:pending()==0);assert(e.backend.close())end
local initial=fd_count()
do
  local e=setup();local a,b,c=submit(e),submit(e),submit(e,"other")
  assert(e.resolved==0);assert(#step(e).events==0)
  assert(status(e,a).state=="starting" and status(e,b).state=="queued" and status(e,c).state=="starting")
  assert(#e.native:pending()==2)
  wait(e,{a,b,c})
  local finished_at,started_at
  for i,v in ipairs(e.events) do
    if v.id==a and v.kind=="finished" then finished_at=i end
    if v.id==b and v.kind=="started" then started_at=i end
  end
  assert(finished_at and started_at and finished_at<started_at)
  for _,ticket in ipairs({a,b,c})do assert(status(e,ticket).state=="finished");assert(e.worker.forget("owner",ticket)) end
  end_test(e)
end
pass("FIFO and independent resources; launching is not started; completion before next start")
do
  local e=setup("ok");local a,b=submit(e,nil,10),submit(e)
  assert(e.worker.cancel("owner",b));e.time=10;step(e)
  assert(status(e,a).state=="expired" and status(e,b).state=="cancelled" and e.resolved==0)
  end_test(e)
  for _,which in ipairs({"ttl","utc"})do
    e=setup("ok",nil,function(env)if which=="ttl"then env.time=10 else env.utc=1010 end;return media_fd end)
    a=submit(e,nil,10,1010);step(e)
    assert(status(e,a).state=="expired" and #e.native:pending()==0);end_test(e)
  end
end
pass("pending cancel/expiry skip resolver; final permit rechecks TTL/UTC after preparation")
do
  local e=setup("ok",nil,function(env)if not env.changed then env.changed=true;env.valid=false end;return media_fd end)
  local a=submit(e,nil,100,2000);step(e)
  assert(status(e,a).state=="queued" and #e.native:pending()==0)
  e.valid=true;wait(e,{a});assert(status(e,a).state=="finished");end_test(e)
end
pass("UTC loss before fork requeues original ticket, recovery keeps original deadline")
do
  local e=setup();local a=submit(e,nil,1);step(e)
  e.time=100;e.bad_clock=true
  local _,err=e.worker.cancel("owner",a);assert(err.code=="active")
  wait(e,{a});assert(status(e,a).state=="finished");end_test(e)
end
pass("active TTL/clock failure never kills child; terminal cleanup still serviced")
do
  for _,mode in ipairs({"exit7","signal","bad"})do
    local e=setup(mode);local a=submit(e);wait(e,{a});local s=status(e,a)
    assert(s.state=="failed")
    if mode=="exit7"then assert(s.exit_code==7 and s.signal==nil)
    elseif mode=="signal"then assert(s.reason=="player_signal" and s.signal==15 and s.exit_code==nil)
    else assert(s.reason=="player_not_started" and s.exit_code==nil)end
    end_test(e)
  end
end
pass("nonzero exit, signal and exec failure stay distinct")
do
  local e=setup("ok",function(p,env)
    local w=wrapper(p);env.allow_release=false
    w.release=function(_,h)if not env.allow_release then return nil,{code="busy"}end;return p:release(h)end
    return w
  end)
  local a,b=submit(e),submit(e)
  for _=1,200 do step(e);if status(e,a).state=="finishing"then break end;pause()end
  assert(status(e,a).state=="finishing" and status(e,b).state=="queued")
  assert(#e.native:pending()==1)
  e.allow_release=true;wait(e,{a,b});end_test(e)
end
pass("terminal process retains queue resource until native release succeeds")
do
  local e=setup("ok",function(p,env)
    local w=wrapper(p);local once=true
    w.begin=function(_,...)
      local h,err=p:begin(...)
      if once and h then once=false;error("lost begin acknowledgement")end
      return h,err
    end
    return w
  end)
  local a,b=submit(e),submit(e,"other");step(e)
  assert(status(e,a).state=="uncertain" and status(e,b).state=="queued")
  assert(#e.native:pending()==1)
  wait(e,{a,b});end_test(e)
end
pass("lost begin result recovers pinned handle; other starts deferred during reconciliation")
do
  local e=setup("ok",function(p)
    local w=wrapper(p);local once=true
    w.release=function(_,h)
      local ok,err=p:release(h)
      if once and ok then once=false;error("lost release acknowledgement")end
      return ok,err
    end
    return w
  end)
  local a,b=submit(e),submit(e);wait(e,{a,b})
  assert(status(e,a).state=="finished" and status(e,b).state=="finished");end_test(e)
  e=setup("ok",function(p)
    local w=wrapper(p);local calls=0
    w.release=function(_,h)
      calls=calls+1
      if calls==1 then error("before release") end
      if calls==2 then return nil,{code="busy"} end
      return p:release(h)
    end
    return w
  end)
  a=submit(e);wait(e,{a});assert(status(e,a).state=="finished");end_test(e)
end
pass("release exceptions before/after cleanup resume without repeat playback")
do
  local e=setup("ok",function(p)
    local w=wrapper(p);local drops=3
    w.poll=function(_,h)if drops>0 then drops=drops-1;error("observe")end;return p:poll(h)end
    return w
  end)
  local a=submit(e);wait(e,{a});local faults=0
  for _,v in ipairs(e.events)do if v.kind=="uncertain"then faults=faults+1 end end
  assert(faults==1);end_test(e)
  e=setup("ok",nil,function()return nil end);a=submit(e);step(e)
  assert(status(e,a).state=="failed" and #e.native:pending()==0);end_test(e)
end
pass("observation failures hold slot with one uncertainty event; missing media never launches")
do
  local e=setup("ok",function(p)
    local w=wrapper(p);local once=true
    w.begin=function(_,...)if once then once=false;error("before begin")end;return p:begin(...)end
    return w
  end)
  local a,b=submit(e),submit(e);wait(e,{a,b})
  assert(status(e,a).reason=="player_begin_unknown" and status(e,b).state=="finished");end_test(e)
  e=setup("ok",function(p)
    local w=wrapper(p)
    w.poll=function(_,h)local s,err=p:poll(h);if s and s.state=="terminal"then s.exec_status="unknown"end;return s,err end
    return w
  end)
  a=submit(e);wait(e,{a});assert(status(e,a).reason=="player_exec_unknown");end_test(e)
end
pass("lost begin before fork is reconciled; exit zero without exec evidence is not success")
collectgarbage("collect");assert(fd_count()==initial)
assert(groups==10);print("PASS queue Linux: 10 groups; no audio/core/router")
