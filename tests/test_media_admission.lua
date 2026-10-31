-- schoolbell TC-72: exact admission-time media leases and real child lifetime.
package.path="src/lua/?.lua;"..package.path
local Media=require("schoolbell.media_linux")
local Native=require("schoolbell.player_linux")
local Queue=require("schoolbell.playback_queue")
local Bridge=require("schoolbell.queue_player")
local n=0
local function pass(s)n=n+1;print("PASS media admission: "..s)end
local function error_is(code,v,e)assert(v==nil and e.code==code,e and e.code)end
local initial=fd_count()
local function catalog()
 local s=Media.new();assert(s:publish("bell","v1",media_fd));return s
end
local function env(store,mode,wrap,max_records)
 local p=assert(Native.new({executable_fd=mode=="bad" and broken_fd or executable_fd,
   lock_directory_fd=directory_fd,argv={"fixture",mode or "hold"},resources={"speaker"}}))
 local e={time=0,native=p}
 local driver=wrap and wrap(p,e) or p
 e.bridge=assert(Bridge.new(driver,function()error("must use admission lease, not resolver")end,{"speaker"}))
 e.q=assert(Queue.new(function()return {mono_ms=e.time,utc_valid=true,utc_ms=1000}end,
   e.bridge,{resources={"speaker"},max_records=max_records or 8},store))
 return e
end
local function request(revision,ttl)
 return {resource="speaker",media_id="bell",media_revision=revision or "v1",ttl_ms=ttl or 5000}
end
local function submit(e,rev,ttl)return assert(e.q.submit("owner",request(rev,ttl))).id end
local function finish(e,ticket)
 for _=1,600 do
  assert(e.q.step());local s=assert(e.q.status("owner",ticket))
  if s.state=="finished" or s.state=="failed" or s.state=="expired" then return s end
  pause()
 end
 error("child timeout")
end
local function wrapper(p)
 return {begin=function(_,...)return p:begin(...)end,poll=function(_,...)return p:poll(...)end,
  release=function(_,...)return p:release(...)end,pending=function()return p:pending()end,
  close=function()return p:close()end}
end
do
 local s=catalog();local e=env(s,"ok",nil,1)
 error_is("media_unavailable",e.q.submit("owner",request("missing")))
 local a=submit(e);error_is("busy",s:remove("bell","v1"));error_is("busy",s:close())
 error_is("full",e.q.submit("owner",request()))
 assert(e.q.cancel("owner",a));assert(s:remove("bell","v1"))
 assert(e.bridge.close());assert(s:close())
end
pass("missing revision rejects admission; queue capacity checked before pin; cancellation drops sole lease")
do
 local s=catalog();local e=env(s)
 local a=submit(e,nil,10);local b=submit(e)
 assert(e.q.cancel("owner",b));error_is("busy",s:remove("bell","v1"))
 e.time=10;assert(e.q.step());assert(e.q.status("owner",a).state=="expired")
 assert(#e.native:pending()==0);assert(s:remove("bell","v1"));assert(e.bridge.close());assert(s:close())
end
pass("shared exact revision; queued cancel and expiry free references without launching")
do
 local s=catalog();local e=env(s)
 local a=submit(e);assert(s:publish("bell","v2",second_media_fd))
 error_is("exists",s:publish("bell","v1",second_media_fd))
 assert(e.q.step());collectgarbage("collect");error_is("busy",s:remove("bell","v1"))
 error_is("active",e.q.cancel("owner",a))
 assert(finish(e,a).state=="finished");assert(s:remove("bell","v1"))
 error_is("exists",s:publish("bell","v1",second_media_fd))
 local b=submit(e,"v2");local result=finish(e,b)
 assert(result.state=="failed" and result.exit_code==91) -- fixture distinguishes v2 content
 assert(e.bridge.close());assert(s:close())
end
pass("new revision never retargets accepted request; active/GC retains v1; removed identity cannot be recycled")
do
 local s=catalog()
 local e=env(s,"ok",function(p,flags)
  flags.block=true;local w=wrapper(p)
  w.release=function(_,h)if flags.block then return nil,{code="busy"}end;return p:release(h)end
  return w
 end)
 local a=submit(e)
 for _=1,200 do e.q.step();if e.q.status("owner",a).state=="finishing"then break end;pause()end
 assert(e.q.status("owner",a).state=="finishing");error_is("busy",s:remove("bell","v1"))
 e.block=false;assert(finish(e,a).state=="finished")
 assert(s:remove("bell","v1"));assert(e.bridge.close());assert(s:close())
end
pass("lease remains through terminal-but-undrained native cleanup")
do
 for _,mode in ipairs({"signal","bad"})do
  local s=catalog();local e=env(s,mode);local a=submit(e)
  assert(finish(e,a).state=="failed");assert(s:remove("bell","v1"))
  assert(e.bridge.close());assert(s:close())
 end
end
pass("signal and exec rejection release media only after confirmed cleanup")
do
 local s=catalog();local e=env(s,"ok",function(p,flags)
  local w=wrapper(p);flags.block=true
  w.poll=function(_,h)if flags.block then error("observation unavailable")end;return p:poll(h)end
  return w
 end)
 local a=submit(e);e.q.step();e.q.step()
 assert(e.q.status("owner",a).state=="uncertain");error_is("busy",s:remove("bell","v1"))
 e.time=10000;e.block=false;finish(e,a)
 assert(s:remove("bell","v1"));assert(e.bridge.close());assert(s:close())
end
pass("uncertain observation and elapsed TTL retain media until outcome is known")
do
 local s=catalog();local lease=assert(s:acquire("bell","v1"))
 local other=Media.new();error_is("invalid_handle",other:release(lease));assert(other:close())
 assert(s:release(lease));assert(s:release(lease));error_is("stale_handle",lease:fd())
 error_is("media_invalid",s:publish("folder","v1",directory_fd))
 error_is("invalid_argument",s:publish("../bad","v1",media_fd))
 local refs={};for i=1,128 do refs[i]=assert(s:acquire("bell","v1")) end
 error_is("limit",s:acquire("bell","v1"))
 for i=1,128 do assert(s:release(refs[i])) end
 fail_allocations();local ok=pcall(s.acquire,s,"bell","v1");allow_allocations()
 assert(not ok);assert(s:remove("bell","v1"));assert(s:close())
end
pass("native lease ownership, idempotent release, strict IDs/regular files, quota and allocation failure")
do
 local s=catalog();local lease=assert(s:acquire("bell","v1"))
 local p=assert(Native.new({executable_fd=executable_fd,lock_directory_fd=directory_fd,
  argv={"fixture","hold"},resources={"speaker"}}))
 local h=assert(p:begin({resource="speaker"},lease:fd(),function()return true end,lease))
 lease=nil;collectgarbage("collect");error_is("busy",s:remove("bell","v1"))
 for _=1,300 do
  local snap=assert(p:poll(h))
  if snap.state=="terminal" and p:release(h) then break end
  pause()
 end
 assert(#p:pending()==0);h=nil;collectgarbage("collect")
 assert(s:remove("bell","v1"));assert(p:close());assert(s:close())
end
pass("native handle pins media lease if caller loses its Lua reference")
do
 local s=Media.new()
 for i=1,16 do assert(s:publish("bell","v"..i,media_fd)) end
 error_is("limit",s:publish("bell","v17",media_fd));assert(s:close())
 s=catalog();local e=env(s,"ok");local a=submit(e)
 replace_media_path();drop_media_source()
 assert(finish(e,a).state=="finished") -- old inode, not replacement bytes
 assert(s:remove("bell","v1"));assert(e.bridge.close());assert(s:close())
end
pass("bounded catalog; admitted inode survives pathname replacement and caller FD close")
collectgarbage("collect");assert(fd_count()==initial-1) -- deliberately closed caller media FD
assert(n==9);print("PASS media admission: 9 groups; no audio/core/router")
