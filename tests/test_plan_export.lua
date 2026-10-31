local F=require('schoolbell.media_fs');local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local host=require('schoolbell.media_fs_host');local base=assert(arg[1]);local cwd=assert(os.getenv('PWD'))
package.loaded['schoolbell.plan_codec']=dofile('src/portable-plan/codec.lua')
local Preview=dofile('src/portable-plan/preview.lua');package.loaded['schoolbell.plan_preview']=Preview;local Codec=package.loaded['schoolbell.plan_codec']
local Admission=require('schoolbell.plan_admission');local Import=require('schoolbell.plan_import')
local function clone(v)return C.decode(C.encode(v))end
local function dirs(name)local p=base..'/'..name;assert(host.mkdir(p));for _,n in ipairs({'editor','media','work'})do assert(host.mkdir(p..'/'..n))end;return p end
local sample=cwd..'/assets/melodies/test.mp3';local f=assert(io.open(sample,'rb'));local audio=f:read('*a');f:close();local hash=C.sha(audio)
local calendar={plans={{id='academic',name='Учебный',start='2027-09-01',['end']='2028-05-31',schedule_ids={'lessons'},days='A'..string.rep('.',273)}},schedules={{id='lessons',name='Уроки',color=4,rows={{id='bell',time='09:00',media='song',enabled=false,pre=true}}}},pre_minutes=2,pre_media='pre'}
for i=2,100 do calendar.schedules[1].rows[i]={id='r'..i,time='09:00',media='song',enabled=false,pre=true}end
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

package.loaded['schoolbell.plan_export']=dofile('src/portable-plan/export.lua')
local Export=require('schoolbell.plan_export_bundle')
local src=dirs('export-source');local original=seed(src)
local e=F.new(src..'/editor',host);local current=S.load(e);local revision=current.revision
local mf=F.new(src..'/media',host);local lib=L.open(mf,src..'/media',function()return true end)
local work=F.new(src..'/work',host)
local function actual(path)return path:gsub('/usr/share/schoolbell%-sound%-test/',cwd..'/assets/melodies/')end
local env={timezone=function()return zone end,version='5.1.21',open=function(path)return assert(io.open(actual(path),'rb'))end,inspect=function(path)
 local f=assert(io.open(actual(path),'rb'));local raw=f:read('*a');f:close();return C.sha(raw),#raw
end}
local before=e.read('current.json',16384);local controls=e.read('sound-control.json',512);local catalog=C.encode(lib.catalog())
local ids=C.decode('["old"]')
assert(not pcall(Export.build,e,lib,work,env,ids,string.rep('f',64)))
assert(not pcall(Export.build,e,lib,work,env,C.decode('["missing"]'),revision))
local space=work.space;work.space=function()return 0,1000000 end;assert(not pcall(Export.build,e,lib,work,env,ids,revision));work.space=space
local ow=work.open_write;work.open_write=function(name)local f=ow(name);if name=='plan.sbp'then return {write=function()return nil end,close=function()return f:close()end}end;return f end
assert(not pcall(Export.build,e,lib,work,env,ids,revision));assert(not work.stat('plan.sbp'));work.open_write=ow
local meta=Export.build(e,lib,work,env,ids,revision);local archive=work.read('plan.sbp',Codec.maximum);assert(#archive==meta.size and C.sha(archive)==meta.sha256)
assert(e.read('current.json',16384)==before and e.read('sound-control.json',512)==controls and C.encode(lib.catalog())==catalog)
assert(not A.decode(e.read(A.name,A.max_bytes)).enabled);work.unlink('plan.sbp');work.close();lib.close();e.close()
-- Real .sbp re-admission and add-only import on a different host directory.
local dst=dirs('export-destination');local admitted=incoming(dst,archive)
assert(#admitted.manifest.files==2 and #admitted.manifest.media==2)
local api=open(dst);local response,proof=api.preview(op,admitted,C.decode('{"plans":{},"schedules":{}}'));assert(response.state=='preview',C.encode(response));assert(api.commit(op,response.preview_token,proof,admitted).state=='committed');api.close()
local e=F.new(dst..'/editor',host);local v=S.load(e);assert(#v.data.plans==1 and v.data.plans[1].start=='2026-01-01'and v.data.plans[1].days=='A');assert(v.data.schedules[1].rows[1].media=='user1');assert(not A.decode(e.read(A.name,A.max_bytes)).enabled);e.close()
local m=F.new(dst..'/media',host);local lib=L.open(m,dst..'/media',function()return true end);assert(lib.list().slots[7].source=='user');assert(m.hash('objects/'..hash)==hash);lib.close()
print('PASS device export/import: real host files, user MP3 and pre-bell, exact hashes, remapped free slot, preserved source, no activation; revision/selection/space/write failure')

-- Real system gateway, host filesystem ports; download callback sees released locks.
local new=F.new;F.new=function(path,_,owner)return new(path,host,owner)end
A.root=src..'/editor';L.root=src..'/media'
package.loaded['nixio.fs']={mkdir=host.mkdir,rmdir=host.rmdir,unlink=host.unlink,stat=function(path)return host.stat(actual(path))end}
package.loaded['luci.util']={copcall=pcall};package.loaded['schoolbell.sound_test']={lock=base..'/gate'}
package.loaded['schoolbell.timezone']={system=function()return {read=function()return {zone='UTC',posix='UTC',pending=false}end,zones=function()return {UTC='UTC'}end,matches=function()return true end,close=function()end}end}
local version=base..'/version';local f=assert(io.open(version,'w'));f:write('5.1.21\n');f:close()
local original_open=io.open;io.open=function(path,mode)if path=='/usr/share/schoolbell-editor/VERSION'then path=version end;return original_open(actual(path),mode)end
local original_popen=io.popen;io.popen=function(cmd,mode)return original_popen(cmd:gsub('/usr/share/schoolbell%-sound%-test/',cwd..'/assets/melodies/'),mode)end
local web=dofile('packaging/openwrt/root/usr/lib/lua/schoolbell/plan_export_web.lua')
local chunks={};local got=web.download(ids,revision,function(meta)local editor=F.new(A.root);editor.close();assert(not host.stat(base..'/gate'));assert(meta.size==#archive)end,function(chunk)chunks[#chunks+1]=chunk end)
assert(got.ok and table.concat(chunks)==archive,C.encode(got))
local failed=web.download(ids,revision,function()end,function()error('disconnected')end);assert(not failed.ok and not host.stat(base..'/gate'))
local next_try=web.download(ids,revision,function()end,function()end);assert(next_try.ok)
print('PASS export system gateway: lock release before response; source snapshot stable; disconnected receiver cleanup and retry; no playback')
