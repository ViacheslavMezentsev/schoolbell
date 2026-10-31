local C=require('schoolbell.media_codec')
local Manager=require('schoolbell.media_manager')
local M={root='/etc/modbus-schoolbell/data',slots={'test','0','1','2','3','4'},sizes={test=13104,['0']=41273,['1']=63321,['2']=69904,['3']=68023,['4']=82368}}
M.titles={test='Тестовый звонок',['0']='[Короткая] Время',['1']='Шутка Баха',['2']='Гостья из XXI',['3']='Князь Игорь',['4']='Усатый нянь'}
M.editable=require('schoolbell.media_ids').user
function M.valid(id)return type(id)=='string' and (M.sizes[id]~=nil or M.editable(id))end
function M.open(fs,root,owned)
 local manager=Manager.new(fs,{ownership_safe=owned});local api={}
 local function read()
  local state=manager.recover();assert(state.state=='ready' or state.state=='empty','recovery_required')
  local catalog=state.state=='ready' and C.decode(fs.read('snapshots/'..state.pointer.current.snapshot..'/catalog.json',16384)) or {melodies=C.decode('[]')}
  return state,catalog
 end
 function api.list()
  local state,cat=read();local slots={}
  local ids={};for _,id in ipairs(M.slots)do ids[#ids+1]=id end
  for _,m in ipairs(cat.melodies)do assert(M.editable(m.id),'bundled override prohibited');ids[#ids+1]=m.id end
  for _,id in ipairs(ids)do
   local v={id=id,name=M.editable(id) and 'Свободная позиция' or id..'.mp3',title=M.titles[id] or ('Пользовательская '..id:sub(5)),source=M.editable(id) and 'empty' or 'bundled',size_bytes=M.sizes[id] or 0}
   for _,m in ipairs(cat.melodies)do if m.id==id then assert(M.editable(id),'bundled override prohibited');local rev=m.revisions[1];v={id=id,name=m.name,title=m.title or m.name,source='user',size_bytes=rev.size_bytes,revision=rev.revision,audio=rev.audio}end end
   slots[#slots+1]=v
  end
  local free,capacity=fs.space();local bytes=0
  for _,h in ipairs(fs.list('objects'))do bytes=bytes+assert(fs.stat('objects/'..h)).size end
  local staging=fs.stat('upload.part');if staging then bytes=bytes+staging.size end
  for _,name in ipairs(fs.list('staging'))do if name:sub(-5)=='.part'then bytes=bytes+assert(fs.stat('staging/'..name)).size end end
  return {ok=true,generation=state.generation or 0,operation_id=state.operation_id,slots=slots,
   storage={total_kib=math.floor(capacity/1024),free_kib=math.floor(free/1024),used_kib=math.ceil(math.max(0,capacity-free)/1024),reserve_kib=math.ceil(math.max(524288,capacity/10)/1024),media_kib=math.ceil(bytes/1024)}}
 end
 function api.resolve(id)
  assert(M.valid(id),'slot');local list=api.list()
  for _,v in ipairs(list.slots)do if v.id==id then assert(v.source~='empty','missing media');return v.source=='user' and root..'/objects/'..v.revision or '/usr/share/schoolbell-sound-test/'..id..'.mp3',v end end
 end
 function api.replace(id,name,expected,op,source,audio,title)
  assert(M.editable(id) and type(name)=='string' and #name>0 and #name<=96 and not name:find('[%c]'),'name')
  local state,cat=read();if expected~=(state.generation or 0)then return {status='conflict'}end
  -- Any unreferenced leftovers are removed only with exclusive ownership.
  if state.state=='ready' then assert(manager.cleanup().status=='cleaned','cleanup')end
  local st=assert(fs.stat('upload.part'));assert(st.size>0 and st.size<=524288,'size')
  local hash=fs.hash('upload.part');local revision={revision=hash,source='user',size_bytes=st.size,audio=audio}
  if title~=nil then assert(type(title)=='string' and #title>0 and #title<=96 and not title:find('[%c]'),'title')end
  local replacement={id=id,name=name,title=title or name,revisions={revision}};local found=false
  for i,m in ipairs(cat.melodies)do if m.id==id then cat.melodies[i]=replacement;found=true end end
  if not found then cat.melodies[#cat.melodies+1]=replacement end
  -- This library holds media overrides only; editor/active plans are not migrated.
  local docs={['catalog.json']=C.encode(cat),['settings.json']='{"scope":"engineering-media-overrides"}',
   ['schedules.json']='{"references":[]}',['plans.json']='{"references":[]}'}
  local free,capacity=fs.space();assert(free>=st.size+65536+math.max(524288,math.ceil(capacity/10)),'space reserve')
  local result=manager.commit(op,expected,docs,{[hash]=source},state.state=='empty')
  if result.status=='saved' then result.revision=hash;result.cleanup=manager.cleanup().status end
  return result
 end
 function api.publish_catalog(cat,expected,op,imports)
  local state=manager.recover()
  if state.state=='ready' and state.operation_id==op then return {status='saved',generation=state.generation}end
  if state.state=='ready' then
   if state.generation~=expected then return {status='conflict'}end
   assert(manager.cleanup().status=='cleaned','cleanup')
  elseif expected==0 and state.state~='empty' then
   -- Explicit pending-restore recovery of OUR interrupted first commit only.
   local allowed={};for _,m in ipairs(cat.melodies)do allowed[m.revisions[1].revision]=true end
   for _,id in ipairs(fs.list('snapshots'))do assert(id==op,'foreign snapshot')end
   for _,h in ipairs(fs.list('objects'))do assert(allowed[h],'foreign object')end
   if fs.stat('current.json')or fs.stat('recovery.json')then error('pointer needs investigation')end
   if fs.stat('snapshots/'..op)then
    local files={['catalog.json']=true,['settings.json']=true,['schedules.json']=true,['plans.json']=true,['snapshot.json']=true}
    for _,name in ipairs(fs.list('snapshots/'..op))do assert(files[name],'foreign file');fs.unlink('snapshots/'..op..'/'..name)end;fs.rmdir('snapshots/'..op)
   end
   for _,h in ipairs(fs.list('objects'))do fs.unlink('objects/'..h)end
   for _,name in ipairs(fs.list('staging'))do assert((name:sub(-5)=='.part' and allowed[name:sub(1,-6)])or name=='current.json.tmp' or name=='recovery.json.tmp','foreign staging');fs.unlink('staging/'..name)end
   fs.sync('objects');fs.sync('snapshots');fs.sync('staging')
  elseif state.state~='empty' then return {status='needs_recovery'}end
  local docs={['catalog.json']=C.encode(cat),['settings.json']='{"scope":"engineering-media-overrides"}',
   ['schedules.json']='{"references":[]}',['plans.json']='{"references":[]}'}
  return manager.commit(op,expected,docs,imports,expected==0)
 end
 function api.catalog()local state,cat=read();return cat,state end
 function api.lookup(op)return manager.lookup(op)end
 function api.close()manager.close()end
 return api
end
return M
