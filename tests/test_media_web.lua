package.path='packaging/openwrt/root/usr/lib/lua/?.lua;'..package.path
local L=require('schoolbell.media_library');local C=require('schoolbell.media_codec');local F=require('schoolbell.media_fs');local host=require('schoolbell.media_fs_host');L.root=assert(arg[1])
assert(host.mkdir(L.root..'/editor'))
local applied=nil
local enabled=false;local decoded=0;local decoder_ok=true
package.loaded['schoolbell.media_fs']={new=function(p)return F.new(p,host)end}
package.loaded.nixio={};package.loaded['nixio.fs']={mkdir=host.mkdir,rmdir=host.rmdir}
package.loaded['schoolbell.sound_test']={lock=L.root..'/gate',run=function()decoded=decoded+1;return decoder_ok and {ok=true} or {ok=false,state='failed'}end}
package.loaded['schoolbell.automatic_store']={root=L.root..'/editor',name='automatic.json',max_bytes=16384,raw=function()return '{}'end,decode=function()return {enabled=enabled,plan=applied}end}
local function copcall(fn,...)
 local co=coroutine.create(fn);local args={...}
 while true do
  local values={coroutine.resume(co,unpack(args))};if not values[1]then return false,values[2]end
  if coroutine.status(co)=='dead'then return unpack(values)end
  table.remove(values,1);args={coroutine.yield(unpack(values))}
 end
end
package.loaded['luci.util']={copcall=copcall}
local function drain(fn)
 local co=coroutine.create(fn);local out={}
 while coroutine.status(co)~='dead'do local ok,v=coroutine.resume(co);assert(ok,v);if v then out[#out+1]=v end end
 return table.concat(out)
end
local W=require('schoolbell.media_web');local f=assert(io.open('assets/melodies/test.mp3','rb'));local bytes=f:read('*a');f:close()
local reads=0;local function run(gen,op,data,disconnect,yielding)
 local at=1;return W.upload({id='user1',name='test.mp3',size=#bytes,generation=gen,operation=string.rep(op,32)},function()
  if yielding then coroutine.yield('read')end;reads=reads+1;if disconnect then return nil,'lost' end
  if at>#data then return nil end;local s=data:sub(at,at+4095);at=at+#s;return s
 end)
end
enabled=true;assert(run(0,'a',bytes).code=='automatic_enabled' and reads==0 and decoded==0);enabled=false
assert(run(0,'a',bytes,true).code=='rejected' and decoded==0 and W.list().generation==0)
assert(run(0,'a',bytes:sub(1,-10)).code=='rejected' and decoded==0)
assert(run(0,'a',string.rep('x',#bytes)).code=='rejected' and decoded==0)
decoder_ok=false;assert(run(0,'a',bytes).code=='rejected' and W.list().generation==0);decoder_ok=true
local saved;drain(function()saved=run(0,'b',bytes,false,true)end);assert(saved.ok and W.list().generation==1 and W.lookup(string.rep('b',32)).state=='retained')
reads=0;assert(run(0,'c',bytes).code=='conflict' and reads==0)
local copied='';assert(W.sample('user1',function(s)copied=copied..s end).ok and copied==bytes)
assert(drain(function()assert(W.sample('user1',function(s)coroutine.yield(s)end).ok)end)==bytes)
local failed;drain(function()failed=W.sample('user1',function()coroutine.yield('chunk');error('disconnected')end)end);assert(not failed.ok and W.list().ok)
print('PASS yielding media upload/download and disconnected sink cleanup on Lua 5.1')
assert(W.lookup(string.rep('d',32)).state=='unknown')
local plan={mode='fixed',fixed_schedule='s',pre_media='test',schedules={{id='s',rows={{media='user5',enabled=true,pre=false}}}}}
assert(not W.plan_ready(plan))
plan.mode='annual';plan.active_plan='p';plan.plans={{id='p',schedule_ids={'s'},days='.'}}
assert(W.plan_ready(plan));plan.plans[1].days='A';assert(not W.plan_ready(plan))
plan.mode='fixed';plan.schedules[1].rows[1].media='user1';assert(W.plan_ready(plan))
for i=2,8 do
 local at=1;local result=W.upload({id='user'..i,name='bell'..i..'.mp3',size=#bytes,generation=i-1,operation=string.rep(tostring(i),32)},function()if at>#bytes then return nil end;local b=bytes:sub(at,at+4095);at=at+#b;return b end);assert(result.ok)
end
assert(W.list().generation==8 and #W.list().slots==14)
plan.schedules[1].rows[1].media='user5';assert(W.plan_ready(plan))
local forbidden=W.upload({id='0',name='no.mp3',size=#bytes,generation=8,operation=string.rep('f',32)},function()error('protected file read')end);assert(forbidden.code=='invalid')
local S=require('schoolbell.schedule_store');local draft=S.empty();draft.schedules={{id='u',name='User',rows={{id='r',time='08:00',media='user5',enabled=true,pre=false}}}};assert(S.validate(C.encode(draft)))
assert(host.mkdir(L.root..'/gate'));assert(W.list().code=='busy');assert(host.rmdir(L.root..'/gate'))
print('PASS media gateway: disabled-auto, stream failure/bounds, invalid MP3, decoder refusal, CAS before read, lookup, preview, gate')

local realload=S.load
S.load=function()return {ok=true,data=draft}end
local op=string.rep('e',32);local at=1
local created=W.upload({id='new',name='dynamic.mp3',title='Новая',size=#bytes,generation=8,operation=op},function()if at>#bytes then return nil end;local b=bytes:sub(at,at+4095);at=at+#b;return b end)
assert(created.ok and created.media_id=='user_'..op and #W.list().slots==15)
assert(W.upload({id='new',name='dynamic.mp3',size=#bytes,generation=9,operation=op},function()error('no duplicate read')end).code=='conflict')
draft.manual_media=created.media_id;draft.pre_media=created.media_id;draft.schedules[1].rows[1].media=created.media_id
assert(S.validate(C.encode(draft)))
S.load=realload
print('PASS dynamic upload: ninth entry, stable generated ID, duplicate blocked, references accepted')

local function deletion(id,gen,op)return W.remove({id=id,generation=gen,operation=string.rep(op,32)})end
assert(deletion('0',9,'a').code=='invalid')
S.load=function()return {ok=true,data=draft}end
assert(deletion(created.media_id,9,'a').code=='in_use')
-- Listing hints come from published files, not the authoritative mutation stub.
local ef=F.new(L.root..'/editor',host);ef.write('current.json',C.encode({data=draft}));ef.close()
assert(W.list().slots[#W.list().slots].in_use)
ef=F.new(L.root..'/editor',host);ef.unlink('current.json');ef.close()
draft=S.empty();applied={pre_media='test',manual_media='user1',schedules={}}
assert(deletion('user1',9,'a').code=='in_use')
applied={pre_media='test',schedules={{rows={{media='user1',enabled=false}}}}}
assert(deletion('user1',9,'a').code=='in_use')
applied=nil;enabled=true;assert(deletion('user1',9,'a').code=='automatic_enabled');enabled=false
assert(deletion('user1',8,'a').code=='conflict')
local locked=F.new(L.root..'/editor',host);assert(not deletion('user1',9,'a').ok);locked.close()
S.load=function()return {ok=false,code='recovery_required'}end
assert(not deletion('user1',9,'a').ok)
S.load=function()return {ok=true,data=draft}end
assert(deletion('user1',9,'a').ok);assert(W.list().generation==10)
assert(not W.sample('user1',function()error('removed media')end).ok)
assert(W.lookup(string.rep('a',32)).state=='retained')
assert(deletion('user1',9,'c').code=='conflict')
assert(deletion('user1',10,'c').code=='missing')
local inspected=require('schoolbell.mp3').inspect
require('schoolbell.mp3').inspect=function()return {format='mp3',duration_ms=1000,sample_rate_hz=44100,channels=1}end
local function sized(n,op)
 local at=0;return W.upload({id='user2',name='size.mp3',size=n,generation=10,operation=string.rep(op,32)},function()if at>=n then return nil end;local k=math.min(4096,n-at);at=at+k;return string.rep('x',k)end)
end
local olddecoded=decoded;assert(sized(65537,'d').code=='invalid'and decoded==olddecoded)
assert(sized(65536,'d').ok);require('schoolbell.mp3').inspect=inspected
S.load=realload
print('PASS delete: bundled protection, draft/applied/disabled row references, auto/generation/editor lock/corruption guards, persisted removal, lookup, 65536/65537 upload boundary')

local savedload=S.load;local olddecode=package.loaded['schoolbell.automatic_store'].decode
S.load=function()error('listing must not validate the draft')end
package.loaded['schoolbell.automatic_store'].decode=function()error('listing must not validate active plan')end
local editorlock=F.new(L.root..'/editor',host)
assert(W.list().ok,'listing must not take editor lock')
editorlock.write('current.json','broken')
local hints=W.list();assert(hints.ok)
for _,v in ipairs(hints.slots)do if v.source=='user'then assert(v.in_use)end end
editorlock.unlink('current.json');editorlock.close()
S.load=savedload;package.loaded['schoolbell.automatic_store'].decode=olddecode
print('PASS fast listing: no full draft/active validation or editor lock; malformed hints disable deletion')

-- TC-199: metadata-only rename preserves the exact audio object and all row references.
for _,title in ipairs({'','   ',' ','　'}) do assert(not require('schoolbell.media_library').valid_title(title)) end
local function rename(id,title,gen,op)return W.rename({id=id,title=title,generation=gen,operation=string.rep(op,32)})end
local listing=W.list();local gen=listing.generation;local original
for _,v in ipairs(listing.slots)do if v.id=='user5' then original=v end end
assert(original)
local before_audio='';assert(W.sample('user5',function(s)before_audio=before_audio..s end).ok)
assert(rename('0','No',gen,'f').code=='invalid')
assert(rename('user5','',gen,'f').code=='invalid')
assert(rename('user5',string.rep('x',97),gen,'f').code=='invalid')
assert(rename('user5','bad\nname',gen,'f').code=='invalid')
assert(rename('user5','   ',gen,'f').code=='invalid')
assert(rename('user5','New',gen-1,'f').code=='conflict')
assert(rename('user99','New',gen,'f').code=='missing')
enabled=true;assert(rename('user5','New',gen,'f').code=='automatic_enabled');enabled=false
assert(host.mkdir(L.root..'/gate'));assert(rename('user5','New',gen,'f').code=='busy');assert(host.rmdir(L.root..'/gate'))
local olddecoded=decoded;assert(rename('user5','Новое название',gen,'f').ok);assert(decoded==olddecoded)
assert(W.lookup(string.rep('f',32)).state=='retained')
local found;for _,v in ipairs(W.list().slots)do if v.id=='user5' then found=v end end
assert(found.title=='Новое название' and found.name==original.name and found.revision==original.revision and found.size_bytes==original.size_bytes)
local after_audio='';assert(W.sample('user5',function(s)after_audio=after_audio..s end).ok);assert(after_audio==before_audio)
assert(plan.schedules[1].rows[1].media=='user5' and W.plan_ready(plan))
assert(rename('user5','Overwrite',gen,'0').code=='conflict')
print('PASS TC-199 rename: protected/invalid/missing, CAS, auto/gate, exact bytes and references preserved, no decoder and retained operation')
