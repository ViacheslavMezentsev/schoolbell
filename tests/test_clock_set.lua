local Set=require('schoolbell.clock_set');local Mail=require('schoolbell.clock_mailbox')
local function setup()
 local x={mono=100,utc=1790000000,zone='UTC',enabled=true,sets=0,stops=0,invalidations=0,releases=0}
 local gate={invalidate=function()x.invalidations=x.invalidations+1 end}
 local ports={monotonic=function()return x.mono end,read=function()return x.utc end,zone=function()return x.zone end,
 stop=function()x.stops=x.stops+1;if x.stop_fail then return false end;x.enabled=false;return true end,
 set=function(n)x.sets=x.sets+1;assert(not x.enabled);if x.raise then error('set failure')end;if x.set_fail then return false end;x.utc=n+(x.skew or 0);return true end,
 lock=function()if x.busy then return nil end;return function()x.releases=x.releases+1;return true end end}
 local run=Set.new(gate,ports)
 local q={action='set_prepare',id=string.rep('a',32),owner=string.rep('b',64),epoch='1790000000'}
 assert(Mail.valid(q));assert(run(q).ok and x.sets==0 and x.stops==0)
 q={action='set_time',id=string.rep('c',32),owner=q.owner,challenge=q.id,ack='true',epoch=q.epoch}
 local function commit()return run(q,{submitted_at=x.mono})end
 return x,q,commit,run,ports,gate
end
local x,q,commit=setup();x.mono=101;q.epoch='1790000001';assert(commit().ok and x.utc==1790000001 and x.invalidations==2 and x.releases==1 and not x.enabled);assert(commit().code=='stale_confirmation' and x.sets==1)
x,q,commit=setup();x.mono=160;assert(commit().code=='stale_confirmation' and x.sets==0)
x,q,commit=setup();q.owner='wrong';assert(commit().code=='stale_confirmation' and x.sets==0)
x,q,commit=setup();x.zone='YEKT-5';assert(commit().code=='stale_confirmation' and x.sets==0)
x,q,commit=setup();q.epoch='1790000020';assert(commit().code=='browser_clock_changed' and x.sets==0)
x,q,commit=setup();x.busy=true;assert(commit().code=='sound_busy' and x.sets==0 and x.stops==0)
x,q,commit=setup();x.stop_fail=true;assert(commit().code=='disable_failed' and x.sets==0 and x.releases==1)
x,q,commit=setup();x.set_fail=true;assert(commit().code=='clock_set_failed' and not x.enabled and x.releases==1)
x,q,commit=setup();x.skew=3;assert(commit().code=='clock_verify_failed' and not x.enabled and x.releases==1)
x,q,commit=setup();x.raise=true;assert(commit().code=='outcome_unknown' and not x.enabled and x.releases==1)
local run,ports,gate;x,q,commit,run,ports,gate=setup();assert(run(q,{submitted_at=94}).code=='clock_request_expired' and x.sets==0)
x,q,commit,run,ports,gate=setup();assert(Set.new(gate,ports)(q,{submitted_at=100}).code=='stale_confirmation')
x,q,commit,run,ports,gate=setup();ports.stop=function()x.enabled=false;x.mono=x.mono+6;return true end;assert(commit().code=='clock_request_expired' and x.sets==0 and x.releases==1)
x,q,commit,run,ports,gate=setup();local setter=ports.set;ports.set=function(n)local ok=setter(n);x.mono=x.mono+3;return ok end;assert(commit().code=='clock_verify_failed' and x.releases==1 and not x.enabled)
x,q,commit,run,ports,gate=setup();x.mono=105;q.epoch='1790000000';assert(run(q,{submitted_at=100}).ok and x.utc==1790000005)
-- Backward correction and small correction both revoke trust, no date/TZ guessing.
x,q,commit=setup();x.utc=1790000100;assert(commit().ok and x.utc==1790000000 and x.invalidations==2)
x,q,commit=setup();x.utc=1790000001;assert(commit().ok and x.invalidations==2)
for _,s in ipairs({'0','1577836799','2145916800','1790000000;reboot','1790000000.5'})do assert(not Set.epoch(s))end
assert(Set.epoch('1577836800') and Set.epoch('2145916799'))
local calls=0
assert(Set.system_set(1577836800,function(cmd)calls=calls+1;assert(cmd=="/bin/date -u -s '2020-01-01 00:00:00' >/dev/null 2>&1");return 0 end))
assert(not Set.system_set(1577836800,function()calls=calls+1;return 256 end));assert(calls==2)
assert(not Set.system_set('1790000000',function()error('must not execute')end))
-- Actual mailbox deduplication around clock side effects.
x,q,commit,run=setup();local files={}
local fs={read=function(k)return files[k]end,stat=function(k)return files[k]~=nil end,write=function(k,v)files[k]=v end,rename=function(a,b)files[b]=files[a];files[a]=nil end,unlink=function(k)files[k]=nil end,close=function()end}
local m=Mail.new(function()return fs end,function()return x.mono end)
assert(m.submit(q).ok);assert(m.process(run).ok);assert(m.submit(q).ok);assert(m.process(run).ok);assert(x.sets==1)
assert(m.poll(q.id,q.owner).ok and m.poll(q.id,'other').pending)
print('PASS browser clock set: fake clocks, confirmation ownership/TTL/step/restart, locks, stop/set/readback faults, UTC command, mailbox dedupe')
