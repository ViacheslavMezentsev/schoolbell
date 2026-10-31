-- Real filesystem adapter and import gateway, with device-only ports substituted.
local host=require('schoolbell.media_fs_host');local F=require('schoolbell.media_fs');local C=require('schoolbell.media_codec');local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local root=assert(arg[1]);local cwd=assert(os.getenv('PWD'));for _,n in ipairs({'editor','media'})do assert(host.mkdir(root..'/'..n))end
A.root=root..'/editor';L.root=root..'/media'
local old_new=F.new;F.new=function(path,_,owner)return old_new(path,host,owner)end
package.loaded['nixio']={};package.loaded['nixio.fs']={mkdir=host.mkdir,rmdir=host.rmdir,stat=host.stat,lstat=host.stat}
package.loaded['luci.util']={copcall=pcall};package.loaded['schoolbell.sound_test']={lock=root..'/gate'}
package.loaded['schoolbell.timezone']={system=function()return {read=function()return {zone='UTC',posix='UTC',pending=false}end,zones=function()return {UTC='UTC'}end,matches=function()return true end,close=function()end}end}
package.loaded['schoolbell.media_web']={decode=function()end}
package.loaded['schoolbell.plan_codec']=dofile('src/portable-plan/codec.lua');package.loaded['schoolbell.plan_preview']=dofile('src/portable-plan/preview.lua')
local popen=io.popen;io.popen=function(cmd,mode)return popen(cmd:gsub('/usr/share/schoolbell%-sound%-test/',cwd..'/assets/melodies/'),mode)end
local api=dofile('packaging/openwrt/root/usr/lib/lua/schoolbell/plan_import_web.lua');api.root=root..'/work'
local sample=assert(io.open('assets/melodies/test.mp3','rb'));local audio=sample:read('*a');sample:close()
local calendar={plans={{id='one',name='Импорт',start='2028-01-01',['end']='2028-01-01',schedule_ids=C.decode('[]'),days='.'}},schedules=C.decode('[]'),pre_minutes=2,pre_media='test'};local body=C.encode(calendar)
local manifest={format='schoolbell-plan/1',exporter={name='schoolbell-pages',version='5.1.20'},timezone={name='UTC',posix='UTC'},files={{name='calendar.json',size_bytes=#body,sha256=C.sha(body)}},media={{id='test',title='Тест',source='bundled',bundled_id='test',size_bytes=#audio,sha256=C.sha(audio)}}}
local m=C.encode(manifest);local bytes='SBPLAN1\n'..string.format('%08d\n',#m)..C.sha(m)..'\n'..m..body;local id=string.rep('c',32)
local function pump(emit)for at=1,#bytes,100 do emit(bytes:sub(at,at+99))end end
local v=api.request('upload',id,nil,pump,#bytes+100);assert(v.state=='validated',C.encode(v))
assert(api.request('status',id).state=='validated')
local preview=api.request('preview',id,{names=C.decode('{"plans":{},"schedules":{}}')});assert(preview.state=='preview',C.encode(preview));assert(#C.encode(preview)<=32768 and preview.space.tmp)
assert(api.request('upload',string.rep('d',32),nil,pump,#bytes+100).code=='busy')
local committed=api.request('commit',id,{preview_token=preview.preview_token});assert(committed.state=='committed',C.encode(committed))
assert(api.request('status',id).state=='committed');assert(api.request('commit',id,{preview_token=preview.preview_token}).state=='committed')
local ed=F.new(A.root);assert(#require('schoolbell.schedule_store').load(ed).data.plans==1);assert(not A.decode(ed.read(A.name,A.max_bytes)).enabled);ed.close()
local bad=string.rep('f',32);local v=api.request('upload',bad,nil,function(emit)emit('broken')end,100);assert(not v.ok);assert(api.request('status',bad).state=='rejected');assert(api.request('cancel',bad).state=='cancelled')
print('PASS system import gateway: upload/preview/commit, operation exclusion, durable replay, rejected input and cancel, actual host files, no playback')
