-- Add-only durable import. Caller owns player -> editor -> media locks.
-- Archive admission is separate; no network, clock adjustment or playback here.
local C=require('schoolbell.media_codec')
local S=require('schoolbell.schedule_store')
local A=require('schoolbell.automatic_store')
local L=require('schoolbell.media_library')
local J=require('modbus.json_strict')
local M={pending='import.pending',stage='import-stage',receipts='import-receipts.json'}
local function clone(v)return assert(J.decode(C.encode(v)))end
local function array()return assert(J.decode('[]'))end
local function envelope(v)return C.encode({data=v,checksum=C.sha(C.encode(v))})end
local function unpack_record(raw)
 local v=C.decode(assert(raw));C.fields(v,{'data','checksum'});assert(C.hex(v.checksum,64)and C.sha(C.encode(v.data))==v.checksum,'record checksum');return v.data
end
function M.new(editor,media,root,env)
 local lib=L.open(media,root,function()return true end)
 local api={};local hook=env.checkpoint or function()end
 local function put(name,raw)
  local tmp='import-next.json';if editor.stat(tmp)then editor.unlink(tmp)end
  editor.write(tmp,raw);editor.sync(tmp);editor.rename(tmp,name);editor.sync('')
 end
 local function receipts()
  local raw=editor.read(M.receipts,540672);return raw and unpack_record(raw)or array()
 end
 local function receipt(id)
  for _,v in ipairs(receipts())do if v.operation_id==id then return v end end
 end
 local function pending()
  local raw=editor.read(M.pending,65536)
  if not raw then return nil end
  local p=unpack_record(raw)
  assert(C.hex(p.operation_id,32)and C.hex(p.archive_sha256,64)and C.hex(p.target_draft,64),'pending')
  assert(p.base_draft=='empty'or C.hex(p.base_draft,64),'base revision')
  assert(C.integer(p.base_media,0,2147483646),'media revision')
  assert(p.target_draft==C.sha(C.encode(p.candidate))and S.validate(C.encode(p.candidate)),'candidate')
  assert(type(p.objects)=='table'and type(p.mapping)=='table','pending fields')
  for hash,v in pairs(p.objects)do assert(C.hex(hash,64)and C.integer(v.size_bytes,1,524288),'object')end
  return p
 end
 local function current()
  assert(not editor.stat('restore.pending'),'recovery_required')
  local draft=S.load(editor);assert(draft.ok,'recovery_required')
  local cat,state=lib.catalog();local auto=A.decode(editor.read(A.name,A.max_bytes))
  return draft,cat,state.generation or 0,auto
 end
 local function space(bytes)
  local free,total=media.space();local reserve=math.max(524288,math.ceil(total/10))
  -- Two audio copies, metadata, all sixteen receipts, and allocation headroom.
  local required=2*bytes+65536+16*32768+131072
  assert(free>=required+reserve,'space')
  local existing=0;for _,name in ipairs(media.list('objects'))do existing=existing+assert(media.stat('objects/'..name)).size end
  -- No separate library quota; free space and archive bounds are checked below.
  return {required=required,free=math.min(free,2147483647),reserve=math.min(reserve,2147483647),capped=free>2147483647 or reserve>2147483647}
 end
 function api.status(id)
  assert(C.hex(id,32),'operation')
  local p=pending();if p and p.operation_id==id then return {ok=true,operation_id=id,state='recovery_required',code='recovery_required'}end
  return receipt(id)or {ok=true,operation_id=id,state='not_found',code=p and 'busy'or 'not_found'}
 end
 -- admitted includes validated source paths/audio; source is supplied by trusted adapter.
 function api.preview(id,admitted,names)
  assert(C.hex(id,32),'operation');assert(not pending(),'recovery_required')
  local old=receipt(id);if old then return old end
  local draft,cat,generation,auto=current()
  local zone=env.timezone();local inventory=env.inventory(lib)
  local v=env.preview(admitted.manifest_raw,admitted.calendar,{draft=draft.data,timezone=zone,media=inventory,operation_id=id,automatic_enabled=auto.enabled,dirty=false,target='device',names=names})
  if not v.ok then return {ok=true,operation_id=id,state='validated',code=v.blockers[1]and v.blockers[1].code or 'format',blockers=v.blockers,blockers_truncated=v.blockers_truncated}end
  local bytes=0;for _,o in pairs(admitted.objects)do bytes=bytes+o.size_bytes end
  local budget=space(bytes)
  local proof={operation_id=id,archive_sha256=admitted.archive_sha256,base_draft=draft.revision,base_media=generation,candidate=v.candidate,mapping=v.mapping,timezone=zone,names=names,pre_change=v.pre_change,issued=math.floor(env.monotonic()),boot=env.boot(),nonce=env.random()}
  assert(C.hex(proof.archive_sha256,64)and C.hex(proof.nonce,64),'proof')
  local token=C.sha(C.encode(proof));proof.preview_token=token
  -- Proof remains in caller's private bounded tmp storage, never accepted from HTTP.
  local response={ok=true,operation_id=id,state='preview',code='ok',preview_token=token,archive_sha256=proof.archive_sha256,draft_revision=draft.revision,media_revision=generation,mapping=v.mapping,timezone=zone,pre_change=v.pre_change,space={persistent=budget},blockers=array(),blockers_truncated=false}
  assert(#C.encode(response)<=32768,'size');return response,proof
 end
 local function clean_stage()
  if not media.stat(M.stage)then return end
  for _,name in ipairs(media.list(M.stage))do assert(C.hex(name,64),'foreign staging');media.unlink(M.stage..'/'..name)end
  media.rmdir(M.stage);media.sync('')
 end
 local function apply(p)
  local draft,cat,generation,auto=current();assert(not auto.enabled,'automatic_enabled')
  assert(C.encode(env.timezone())==C.encode(p.timezone),'timezone')
  assert(draft.revision==p.base_draft or draft.revision==p.target_draft,'conflict')
  assert(generation==p.base_media or generation==p.base_media+1,'conflict')
  local imports={}
  for hash,v in pairs(p.objects)do
   local path=M.stage..'/'..hash;local st=assert(media.stat(path),'staging missing')
   assert(st.size==v.size_bytes and media.hash(path)==hash,'staging checksum')
   imports[hash]=root..'/'..path
  end
  if next(p.objects)then
   local result=lib.publish_catalog(p.catalog,p.base_media,p.operation_id,imports)
   assert(result.status=='saved','media publication')
  else assert(generation==p.base_media,'conflict')end
  hook('media')
  if draft.revision~=p.target_draft then
   local old=editor.read('current.json',S.file_bytes)
   if old then put('previous.json',old)end
   put('current.json',envelope(p.candidate))
  end
  hook('draft')
  local after,actual,mg,enabled=current()
  assert(after.revision==p.target_draft and not enabled.enabled,'verify')
  assert(C.encode(actual)==C.encode(p.catalog),'catalog verify')
  assert(mg==p.base_media+(next(p.objects)and 1 or 0),'generation verify')
  hook('verified')
  local done={ok=true,operation_id=p.operation_id,state='committed',code='ok',result={draft_revision=p.target_draft,media_revision=mg,automatic_enabled=false},mapping=p.mapping}
  assert(#C.encode(done)<=32768,'receipt size')
  local all=receipts();local found=false
  for i,v in ipairs(all)do if v.operation_id==p.operation_id then all[i]=done;found=true end end
  if not found then all[#all+1]=done end
  while #all>16 do table.remove(all,1)end
  put(M.receipts,envelope(all));hook('receipt')
  editor.unlink(M.pending);editor.sync('');hook('complete')
  pcall(clean_stage) -- verified commit cannot become failure because cleanup failed
  return done
 end
 function api.commit(id,token,proof,admitted)
  assert(C.hex(id,32)and C.hex(token,64),'format')
  local p=pending();if p then return {ok=false,operation_id=id,state='recovery_required',code='recovery_required'}end
  local done=receipt(id);if done then return done end
  assert(proof and proof.operation_id==id and proof.preview_token==token,'conflict')
  local check=clone(proof);check.preview_token=nil;assert(C.sha(C.encode(check))==token,'conflict')
  assert(proof.boot==env.boot()and env.monotonic()>=proof.issued and env.monotonic()-proof.issued<=900,'expired')
  assert(admitted.archive_sha256==proof.archive_sha256,'conflict')
  local before,cat,generation,auto=current()
  assert(not auto.enabled,'automatic_enabled')
  assert(before.revision==proof.base_draft and generation==proof.base_media,'conflict')
  assert(C.encode(env.timezone())==C.encode(proof.timezone),'timezone')
  local preview=env.preview(admitted.manifest_raw,admitted.calendar,{draft=before.data,timezone=proof.timezone,media=env.inventory(lib),operation_id=id,automatic_enabled=false,dirty=false,target='device',names=proof.names})
  assert(preview.ok and C.encode(preview.candidate)==C.encode(proof.candidate)and C.encode(preview.mapping)==C.encode(proof.mapping),'conflict')
  local bytes=0;for _,v in pairs(admitted.objects)do bytes=bytes+v.size_bytes end;space(bytes)
  clean_stage();media.mkdir(M.stage)
  local ok,value=pcall(function()
   for hash,v in pairs(admitted.objects)do
    assert(C.hex(hash,64),'object');media.copy(v.path,M.stage..'/'..hash,524288)
    assert(media.stat(M.stage..'/'..hash).size==v.size_bytes and media.hash(M.stage..'/'..hash)==hash,'checksum')
    media.sync(M.stage..'/'..hash)
   end
   media.sync(M.stage);media.sync('');hook('staged')
   local catalog=clone(cat);local used={};for _,m in ipairs(cat.melodies)do used[m.id]=true end
   local incoming={};for _,m in ipairs(admitted.manifest.media)do incoming[m.id]=m end
   for _,map in ipairs(proof.mapping.media)do
    local m=incoming[map.old_id]
    if m.source=='user'then
     assert(not used[map.slot],'slots');used[map.slot]=true
     local v=assert(admitted.objects[m.sha256])
     catalog.melodies[#catalog.melodies+1]={id=map.slot,name=m.sha256..'.mp3',title=m.title,revisions={{revision=m.sha256,source='user',size_bytes=m.size_bytes,audio=v.audio}}}
    end
   end
   local objects={};for hash,v in pairs(admitted.objects)do objects[hash]={size_bytes=v.size_bytes}end
   local record={operation_id=id,archive_sha256=proof.archive_sha256,base_draft=before.revision,base_media=generation,target_draft=C.sha(C.encode(proof.candidate)),candidate=proof.candidate,catalog=catalog,mapping=proof.mapping,objects=objects,timezone=proof.timezone}
   local raw=envelope(record);assert(#raw<=65536,'size')
   put(M.pending,raw);hook('intent');return apply(record)
  end)
  if ok then return value end
  local exists=editor.stat(M.pending)
  if not exists then local done=receipt(id);if done then return done end;pcall(clean_stage)end
  return {ok=false,operation_id=id,state=exists and 'recovery_required'or 'rejected',code=exists and 'recovery_required'or 'storage_unavailable'}
 end
 function api.resume(id)
  assert(C.hex(id,32),'format');local p=pending()
  if not p then return receipt(id)or {ok=false,operation_id=id,state='not_found',code='not_found'}end
  assert(p.operation_id==id,'conflict')
  local ok,value=pcall(apply,p)
  return ok and value or {ok=false,operation_id=id,state='recovery_required',code='recovery_required'}
 end
 function api.close()lib.close();editor.close()end
 return api
end
return M
