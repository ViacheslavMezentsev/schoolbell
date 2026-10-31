local C=require('schoolbell.media_codec');local Codec=require('schoolbell.backup_codec')
local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store');local Controls=require('schoolbell.controls');local L=require('schoolbell.media_library')
local M={}
function M.new(editor,media,root,env)
 local protect=env.protect or pcall;local lib=L.open(media,root,function()return true end);local hook=env.checkpoint or function()end;local api={}
 local function pending()
  local raw=editor.read('restore.pending',4096);if not raw then return nil end
  local envelope=C.decode(raw);C.fields(envelope,{'data','checksum'});local p=envelope.data
  assert(C.sha(C.encode(p))==envelope.checksum,'pending checksum')
  C.fields(p,{'operation_id','manifest_hash','media_generation','auto_generation','control_generation','watermark','olddraft_hash'})
  assert(C.hex(p.operation_id,32) and C.hex(p.manifest_hash,64) and C.integer(p.media_generation,0,2147483646) and C.integer(p.auto_generation,1,2147483647) and C.integer(p.control_generation,1,2147483647) and C.integer(p.watermark,0,2147483647),'pending')
  assert(p.olddraft_hash==C.null or C.hex(p.olddraft_hash,64),'old draft');return p
 end
 function api.status()local p=pending();local last=editor.read('restore-last.json',4096);last=last and C.decode(last);return {ok=true,pending=p~=nil,operation_id=p and p.operation_id or nil,last_operation=last and last.operation_id or nil}end
 function api.export(write)
  assert(not pending(),'restore_pending');local auto=A.decode(editor.read(A.name,A.max_bytes));assert(not auto.enabled,'automatic_enabled')
  local draft=S.load(editor);assert(draft.ok,'draft');local controls=Controls.decode(editor.read('sound-control.json',512))
  local cat=lib.catalog();local _,objects,ids=Codec.catalog(C.encode(cat))
  local function ref(id)assert(not L.editable(id) or ids[id],'missing melody reference')end
  ref(draft.data.pre_media);ref(draft.data.manual_media or 'test');for _,s in ipairs(draft.data.schedules)do for _,row in ipairs(s.rows)do ref(row.media)end end
  local docs={['draft.json']=C.encode(draft.data),['controls.json']=C.encode({muted=controls.muted,volume_db=controls.volume_db}),['catalog.json']=C.encode(cat)}
  local extended=#cat.melodies>8;for _,m in ipairs(cat.melodies)do if not m.id:match('^user[1-8]$')then extended=true end end
  local manifest={format=extended and 'schoolbell-backup/2' or 'schoolbell-backup/1',timezone=env.timezone,files={}}
  for _,name in ipairs({'draft.json','controls.json','catalog.json'})do local raw=docs[name];assert(#raw<=16384);manifest.files[#manifest.files+1]={name=name,size_bytes=#raw,sha256=C.sha(raw)}end
  local hashes={};for hash in pairs(objects)do hashes[#hashes+1]=hash end;table.sort(hashes)
  for _,hash in ipairs(hashes)do manifest.files[#manifest.files+1]={name=hash..'.mp3',size_bytes=objects[hash].size_bytes,sha256=hash}end
  local raw=C.encode(manifest);Codec.manifest(raw);write(Codec.magic..string.format('%08d\n',#raw)..C.sha(raw)..'\n'..raw)
  for _,v in ipairs(manifest.files)do
   if docs[v.name]then write(docs[v.name])else
    local f=media.open_read('objects/'..v.sha256);local ok,why=protect(function()while true do local chunk=f:read(16384);if not chunk then break end;write(chunk)end end);f:close();assert(ok,why)
   end
  end
  return {ok=true}
 end
 local function put(name,raw)
  if editor.stat('restore-next.json')then editor.unlink('restore-next.json')end
  editor.write('restore-next.json',raw);editor.sync('restore-next.json');editor.rename('restore-next.json',name);editor.sync('')
 end
 local function apply(p,v)
  assert(p.manifest_hash==v.manifest_hash,'different staged archive')
  local disabled={enabled=false,generation=p.auto_generation,watermark=p.watermark}
  put(A.name,C.encode({data=disabled,checksum=C.sha(C.encode(disabled))}));hook('disabled')
  local imports={};for hash in pairs(v.objects)do imports[hash]=root..'/'..Codec.stage..'/'..hash..'.mp3' end
  local result=lib.publish_catalog(v.catalog,p.media_generation,p.operation_id,imports);assert(result.status=='saved','media publication');hook('media')
  if p.olddraft_hash~=C.null then
   local old=assert(media.read(Codec.stage..'/rollback-draft.json',16384));assert(C.sha(old)==p.olddraft_hash,'old draft checksum');put('previous.json',old)
  end
  local body=C.encode(v.draft);put('current.json',C.encode({data=v.draft,checksum=C.sha(body)}));hook('draft')
  put('sound-control.json',C.encode({muted=v.controls.muted,volume_db=v.controls.volume_db,generation=p.control_generation}));hook('controls')
  assert(S.load(editor).revision==C.sha(body),'draft verify');assert(not A.decode(editor.read(A.name,A.max_bytes)).enabled,'auto verify')
  local control=Controls.decode(editor.read('sound-control.json',512));assert(control.muted==v.controls.muted and control.volume_db==v.controls.volume_db,'control verify')
  assert(lib.lookup(p.operation_id).state=='retained','media verify');hook('verified')
  put('restore-last.json',C.encode({operation_id=p.operation_id,draft_revision=C.sha(body),automatic_enabled=false}));editor.unlink('restore.pending');editor.sync('');hook('complete')
  -- Cleanup failure cannot undo a durable, verified restore.
  local cleaned=pcall(Codec.clean,media);return {ok=true,state='restored',automatic_enabled=false,cleanup=cleaned}
 end
 function api.restore(operation,source,size)
  assert(C.hex(operation,32),'operation');if pending()then return {ok=false,code='restore_pending'}end
  local auto=A.decode(editor.read(A.name,A.max_bytes));assert(not auto.enabled,'automatic_enabled')
  local controls=Controls.decode(editor.read('sound-control.json',512));assert(auto.generation<2147483647 and controls.generation<2147483647,'generation exhausted')
  local old=S.load(editor);assert(old.ok,'existing draft needs investigation')
  local free,total=media.space();assert(C.integer(size,1,Codec.maximum) and free>=size+65536+math.max(524288,math.ceil(total/10)),'space')
  local started=false
  local ok,result=protect(function()
   Codec.receive(media,source,size,protect);local v=Codec.validate(media,root,env.timezone,env.decode);hook('validated')
   local _,state=lib.catalog();local incoming=0;local objectbytes=0;local stagedbytes=0
   for hash,m in pairs(v.objects)do stagedbytes=stagedbytes+m.size_bytes;if not media.stat('objects/'..hash)then incoming=incoming+m.size_bytes end end
   for _,hash in ipairs(media.list('objects'))do objectbytes=objectbytes+assert(media.stat('objects/'..hash)).size end
   -- Physical free-space admission below includes staged and incoming files.
   free,total=media.space();assert(free>=incoming+131072+math.max(524288,math.ceil(total/10)),'space peak')
   local oldraw=editor.read('current.json',16384);local oldhash=C.null
   if oldraw then media.write(Codec.stage..'/rollback-draft.json',oldraw);media.sync(Codec.stage..'/rollback-draft.json');media.sync(Codec.stage);oldhash=C.sha(oldraw)end
   local p={operation_id=operation,manifest_hash=v.manifest_hash,media_generation=state.generation or 0,auto_generation=auto.generation+1,control_generation=controls.generation+1,watermark=math.max(auto.watermark,env.now),olddraft_hash=oldhash}
   started=true;put('restore.pending',C.encode({data=p,checksum=C.sha(C.encode(p))}));hook('pending')
   return apply(p,v)
  end)
  if not ok then
   local exists=editor.stat('restore.pending')~=nil
   if not exists and (not env.safe_cleanup or env.safe_cleanup())then pcall(Codec.clean,media)end
   return {ok=false,code=exists and 'restore_pending' or started and 'restore_uncertain' or 'rejected'}
  end;return result
 end
 function api.resume(operation)
  local p=assert(pending(),'no pending restore');assert(p.operation_id==operation,'operation mismatch')
  local ok,result=protect(function()return apply(p,Codec.validate(media,root,env.timezone,env.decode))end)
  return ok and result or {ok=false,code='restore_pending'}
 end
 function api.close()lib.close();editor.close()end
 return api
end
return M
