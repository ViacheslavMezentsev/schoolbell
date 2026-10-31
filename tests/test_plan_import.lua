local F=require('schoolbell.media_fs');local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local host=require('schoolbell.media_fs_host');local base=assert(arg[1]);local cwd=assert(os.getenv('PWD'))
package.loaded['schoolbell.plan_codec']=dofile('src/portable-plan/codec.lua')
local Preview=dofile('src/portable-plan/preview.lua');package.loaded['schoolbell.plan_preview']=Preview;local Codec=package.loaded['schoolbell.plan_codec']
local Admission=require('schoolbell.plan_admission');local Import=require('schoolbell.plan_import')
local function clone(v)return C.decode(C.encode(v))end
local function dirs(name)local p=base..'/'..name;assert(host.mkdir(p));for _,n in ipairs({'editor','media','work'})do assert(host.mkdir(p..'/'..n))end;return p end
local sample=cwd..'/assets/melodies/test.mp3';local f=assert(io.open(sample,'rb'));local audio=f:read('*a');f:close();local hash=C.sha(audio)
local calendar={plans={{id='academic',name='Учебный',start='2027-09-01',['end']='2028-05-31',schedule_ids={'lessons'},days='A'..string.rep('.',273)}},schedules={{id='lessons',name='Уроки',color=4,rows={{id='bell',time='09:00',media='song',enabled=false,pre=true}}}},pre_minutes=2,pre_media='pre'}
local cal=C.encode(calendar)
local manifest={format='schoolbell-plan/1',exporter={name='schoolbell-device',version='5.1.20'},timezone={name='UTC',posix='UTC'},files={{name='calendar.json',size_bytes=#cal,sha256=C.sha(cal)},{name='media/'..hash..'.mp3',size_bytes=#audio,sha256=hash}},media={{id='pre',title='Тест',source='bundled',bundled_id='test',size_bytes=#audio,sha256=hash},{id='song',title='Урок',source='user',file='media/'..hash..'.mp3',size_bytes=#audio,sha256=hash}}}
local raw=C.encode(manifest);local bytes=Codec.magic..string.format('%08d\n',#raw)..C.sha(raw)..'\n'..raw..cal..audio
local now,zone=100,{name='UTC',posix='UTC'};local op=string.rep('a',32)
local function incoming(p,data)
 local w=F.new(p..'/work',host);local at=1;local s=data or bytes
 local ok,v=pcall(Admission.receive,w,function()if at>#s then return nil end;local c=s:sub(at,at+999);at=at+#c;return c end,#s,{work_root=p..'/work',monotonic=function()return now end,inspect=require('schoolbell.mp3').inspect})
 w.close();assert(ok,v);return v
end
local function inventory(lib)
 local result={{id='test',size_bytes=#audio,sha256=hash}}
 for _,v in ipairs(lib.list().slots)do if v.source=='user'then result[#result+1]={id=v.id,size_bytes=v.size_bytes,sha256=v.revision}end end
 return result
end
local function open(p,hook)
 return Import.new(F.new(p..'/editor',host,'import'),F.new(p..'/media',host),p..'/media',{monotonic=function()return now end,boot=function()return 'boot' end,random=function()return string.rep('b',64)end,timezone=function()return zone end,inventory=inventory,preview=Preview.preview,checkpoint=hook})
end
local function seed(p)
 local e=F.new(p..'/editor',host);local draft=S.empty();draft.schedules={{id='existing',name='Существующее',rows={{id='old',time='10:00',media='user8',enabled=true,pre=false}}}};draft.plans={{id='old',name='Старый план',start='2026-01-01',['end']='2026-01-01',schedule_ids={'existing'},days='A'}}
 assert(S.save(e,C.encode(draft),'empty').ok);e.write('sound-control.json','{"muted":true,"generation":2,"volume_db":-18}');e.close()
 local mf=F.new(p..'/media',host);local lib=L.open(mf,p..'/media',function()return true end);mf.copy(sample,'upload.part',524288);assert(lib.replace('user8','old.mp3',0,string.rep('e',32),p..'/media/upload.part',require('schoolbell.mp3').inspect(sample),'Существующая').status=='saved');mf.unlink('upload.part');lib.close();return draft
end
local function verify(p,old)
 local e=F.new(p..'/editor',host);local v=S.load(e);assert(v.ok and #v.data.plans==2 and #v.data.schedules==2)
 assert(C.encode(v.data.plans[1])==C.encode(old.plans[1])and C.encode(v.data.schedules[1])==C.encode(old.schedules[1]))
 assert(e.read('sound-control.json',512)=='{"muted":true,"generation":2,"volume_db":-18}');assert(not A.decode(e.read(A.name,A.max_bytes)).enabled);e.close()
 local mf=F.new(p..'/media',host);local lib=L.open(mf,p..'/media',function()return true end);local cat=lib.catalog();assert(#cat.melodies==2 and cat.melodies[1].id=='user8'and cat.melodies[2].id=='user1');assert(cat.melodies[1].title=='Существующая');assert(lib.resolve('user1')==p..'/media/objects/'..hash);lib.close()
end
local names=C.decode('{"plans":{},"schedules":{}}')
local p=dirs('roundtrip');local old=seed(p);local admitted=incoming(p);local api=open(p);local result,proof=api.preview(op,admitted,names);assert(result.state=='preview'and proof)
assert(api.commit(op,result.preview_token,proof,admitted).state=='committed');assert(api.commit(op,result.preview_token,proof,admitted).state=='committed');api.close();verify(p,old)
print('PASS add-only import: academic/cross-year plan, disabled media dependency, free slot, preserved old plans/audio/settings, replay receipt, auto off')
for _,point in ipairs({'staged','intent','media','draft','verified','receipt','complete'})do
 local p=dirs('fault-'..point);local old=seed(p);local admitted=incoming(p);local api=open(p,function(at)if at==point then error('injected crash')end end)
 local response,proof=api.preview(op,admitted,names);local done=api.commit(op,response.preview_token,proof,admitted);api.close()
 if point=='staged'then local e=F.new(p..'/editor',host);assert(#S.load(e).data.plans==1);e.close()
 else
  if point~='complete'then assert(not pcall(F.new,p..'/editor',host),'ordinary editor must block pending')end
  api=open(p);assert(api.resume(op).state=='committed');api.close();verify(p,old)
 end
 print('PASS import interruption '..point)
end
local p=dirs('conflicts');seed(p);local admitted=incoming(p);local api=open(p);local res,proof=api.preview(op,admitted,names);now=1001;assert(not pcall(api.commit,op,res.preview_token,proof,admitted));now=100;zone={name='Other',posix='UTC'};assert(not pcall(api.commit,op,res.preview_token,proof,admitted));zone={name='UTC',posix='UTC'};api.close()
local e=F.new(p..'/editor',host);local v=S.load(e);v.data.pre_minutes=3;assert(S.save(e,C.encode(v.data),v.revision).ok);e.close();api=open(p);assert(not pcall(api.commit,op,res.preview_token,proof,admitted));api.close()
print('PASS expired proof, changed timezone and changed draft reject without publication')
for _,case in ipairs({'truncated','tail','checksum'})do
 local p=dirs(case);local b=case=='truncated'and bytes:sub(1,-2)or case=='tail'and(bytes..'x')or(bytes:sub(1,-2)..'x');assert(not pcall(incoming,p,b));local e=F.new(p..'/editor',host);assert(S.load(e).revision=='empty');e.close()
end
print('PASS corrupt archives do not publish data')

-- A failure at each primitive write/sync/rename must not expose a partial draft.
local mutations={'write','sync','rename','copy','unlink','mkdir','rmdir'}
local function fault_open(p,at,after)
 local ed,mf=F.new(p..'/editor',host,'import'),F.new(p..'/media',host);local count=0;local armed=false
 for _,backend in ipairs({ed,mf})do for _,name in ipairs(mutations)do local original=backend[name]
  backend[name]=function(...)if armed then count=count+1 end;local hit=armed and count==at;if hit and not after then error('injected primitive failure')end;local v=original(...);if hit then error('injected primitive failure')end;return v end
 end end
 local api=Import.new(ed,mf,p..'/media',{monotonic=function()return now end,boot=function()return 'boot' end,random=function()return string.rep('b',64)end,timezone=function()return zone end,inventory=inventory,preview=Preview.preview});armed=true;return api,function()return count end
end
local p=dirs('count-io');seed(p);local admitted=incoming(p);local api,count=fault_open(p,-1,false);local res,proof=api.preview(op,admitted,names);assert(api.commit(op,res.preview_token,proof,admitted).state=='committed');local steps=count();api.close()
for _,after in ipairs({false,true})do for at=1,steps do
 local p=dirs('io-'..tostring(after)..'-'..at);local old=seed(p);local admitted=incoming(p);local api=open(p);local res,proof=api.preview(op,admitted,names);api.close()
 api=fault_open(p,at,after);pcall(api.commit,op,res.preview_token,proof,admitted);pcall(api.close)
 local probe=F.new(p..'/editor',host,'import');local barrier=probe.stat('import.pending');local draft=S.load(probe);assert(draft.ok);assert(#draft.data.plans==1 or #draft.data.plans==2);assert(C.encode(draft.data.plans[1])==C.encode(old.plans[1]));probe.close()
 if barrier then assert(not pcall(F.new,p..'/editor',host));local recovered=open(p);local result=recovered.resume(op);recovered.close();assert(result.state=='committed'or result.state=='recovery_required');if result.state=='committed'then verify(p,old)end
 elseif #draft.data.plans==2 then verify(p,old)end
end end
print('PASS primitive fault matrix before/after '..steps..' writes/syncs/renames/copies: complete state or explicit recovery barrier')
