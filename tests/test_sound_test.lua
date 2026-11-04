package.path="src/lua/?.lua;vendor/?.lua;packaging/openwrt/root/usr/lib/lua/?.lua;"..package.path
local m=require("schoolbell.sound_test")
local groups=0
local function fixture()
 local x={released=0,killed=0,slept=0,waited=0,spawned=0}
 x.ready=function() return true end
 x.acquire=function() return true end
 x.release=function() x.released=x.released+1; return true end
 x.spawn=function() x.spawned=x.spawned+1; return 42 end
 x.wait=function(pid) assert(pid==42); x.waited=x.waited+1; return 42,"exited",0 end
 x.sleep=function() x.slept=x.slept+1 end
 x.kill=function(pid) assert(pid==42); x.killed=x.killed+1 end
 return x
end
local function check(name,fn) fn(); groups=groups+1; print("PASS "..name) end
check("success/reap/release",function()
 local x=fixture(); assert(m.run(x).state=="completed"); assert(x.released==1 and x.killed==0)
end)
check("unavailable",function()
 local x=fixture(); x.ready=function() return false end
 assert(m.run(x).state=="unavailable"); assert(x.spawned==0 and x.released==0)
end)
check("busy",function()
 local x=fixture(); x.acquire=function() return false end
 assert(m.run(x).state=="busy"); assert(x.spawned==0 and x.released==0)
end)
check("fork failure",function()
 local x=fixture(); x.spawn=function() return nil end
 assert(m.run(x).state=="spawn_failed" and x.released==1)
end)
check("exit failure",function()
 local x=fixture(); x.wait=function() return 42,"exited",127 end
 local out=m.run(x); assert(out.state=="failed" and not out.ok and out.exit_code==127)
end)
check("signal failure",function()
 local x=fixture(); x.wait=function() return 42,"signaled",9 end
 assert(m.run(x).state=="failed" and x.released==1)
end)
check("pending and completion",function()
 local x=fixture(); x.wait=function() x.waited=x.waited+1; if x.waited<4 then return false end; return 42,"exited",0 end
 assert(m.run(x).ok and x.slept==3 and x.released==1)
end)
check("timeout kill and reap",function()
 local x=fixture(); x.wait=function() if x.killed==0 then return false end; return 42,"signaled",9 end
 assert(m.run(x).state=="timeout"); assert(x.killed==1 and x.slept==100 and x.released==1)
end)
check("uncertain wait retains lock",function()
 local x=fixture(); x.wait=function() return nil,"error" end
 assert(m.run(x).state=="recovery_required" and x.released==0 and x.killed==0)
end)
check("unreaped killed child retains lock",function()
 local x=fixture(); x.wait=function() return false end
 assert(m.run(x).state=="recovery_required"); assert(x.released==0 and x.slept==120 and x.killed==1)
end)
check("cleanup failure",function()
 local x=fixture(); x.release=function() return false end
 assert(m.run(x).state=="cleanup_required")
end)
check("target nixio modes, descriptors and fixed argv",function()
 local fd={close=function() end}; local stdin,stdout,stderr={},{},{};local gain="0"
 package.loaded.nixio={stdin=stdin,stdout=stdout,stderr=stderr,
   fork=function() return 0 end,
   open=function(path,mode) assert(path=="/dev/null" and mode=="r+"); return fd end,
   dup=function(f,to) assert(f==fd and (to==stdin or to==stdout or to==stderr)); return true end,
   exec=function(...)
     local a={...}; assert(#a==9 and a[1]=="/usr/bin/madplay" and a[2]=="--no-tty-control")
     assert(a[3]=="-a" and a[4]==gain and a[5]=="-R" and a[6]=="48000")
     assert(a[7]=="-o" and a[8]=="/dev/dsp" and a[9]==m.sample)
     error("exec-fixture-success")
   end}
 package.loaded["nixio.fs"]={}
 local ok,err=pcall(m.system().spawn)
 assert(not ok and tostring(err):find("exec%-fixture%-success"))
 local original=package.loaded['schoolbell.controls'];gain='-12'
 package.loaded['schoolbell.controls']={read=function()return {muted=false,generation=0,volume_db=-12}end}
 ok,err=pcall(m.system().spawn);assert(not ok and tostring(err):find('exec%-fixture%-success'))
 package.loaded['schoolbell.controls']=original
end)
check("mute rejects before spawn",function()
 local x=fixture();x.muted=function()return true end;assert(m.run(x).state=='muted' and x.spawned==0)
end)
check("mute rechecked after acquiring lock",function()
 local x=fixture();local calls=0;x.muted=function()calls=calls+1;return calls>1 end
 assert(m.run(x).state=='muted' and x.spawned==0 and x.released==1)
end)
check("mute stops owned child and reaps",function()
 local x=fixture();local polls=0;x.muted=function()polls=polls+1;return polls>=3 end
 x.wait=function()if x.killed>0 then return 42,'signaled',9 end;return false end
 assert(m.run(x).state=='muted' and x.killed==1 and x.released==1)
end)
check("mute cannot confirm unobserved child exit",function()
 local x=fixture();local polls=0;x.muted=function()polls=polls+1;return polls>=3 end
 x.wait=function()return false end
 assert(m.run(x).state=='recovery_required' and x.released==0)
end)
-- Controller test: neither a rejected method nor CSRF may enter the backend.
package.loaded["schoolbell.controls"]={snapshot=function()return {ok=true,confirm_play=false}end}
local allowed=false; local runs=0; local response
package.loaded["luci.dispatcher"]={test_post_security=function() return allowed end}
package.loaded["luci.http"]={formvalue=function()return nil end,header=function() end,prepare_content=function() end,write_json=function(v) response=v end}
package.loaded["schoolbell.sound_test"]={system=function() return {} end,run=function() runs=runs+1; return {state="completed",ok=true} end}
dofile("packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua")
check("rejected POST does not play",function()
 luci.controller.schoolbell_test.play(); assert(runs==0)
end)
check("accepted POST returns result",function()
 allowed=true; luci.controller.schoolbell_test.play(); assert(runs==1 and response.ok)
end)
print("schoolbell sound test: "..groups.." groups passed")
