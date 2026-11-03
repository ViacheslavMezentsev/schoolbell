-- Engineering media gateway: same exclusive gate as the diagnostic player.
local M={}
-- LuCI request sources and response sinks may yield on Lua 5.1.
local protect=require('luci.util').copcall
local L=require('schoolbell.media_library');local C=require('schoolbell.media_codec')
local function session(fn,lock_editor)
 local n,fs=require('nixio'),require('nixio.fs');local lock=require('schoolbell.sound_test').lock
 if not fs.mkdir(lock,700)then return {ok=false,code='busy'}end
 local backend,library,editorfs;local keep=false
 local ok,value=protect(function()
  local editor=require('schoolbell.automatic_store').root or '/etc/schoolbell-editor'
  assert(not fs.lstat or not fs.lstat(editor..'/import.pending'),'import_pending')
  assert(not fs.lstat or not fs.lstat(editor..'/restore.pending'),'restore_pending')
  if lock_editor then editorfs=require('schoolbell.media_fs').new(editor)end
  backend=require('schoolbell.media_fs').new(L.root)
  library=L.open(backend,L.root,function()return true end)
  return fn(library,backend,function()keep=true end,editorfs)
 end)
 local closed=true;if library then closed=pcall(library.close)elseif backend then closed=pcall(backend.close)end
 if editorfs and not pcall(editorfs.close)then closed=false end
 if not keep then if not fs.rmdir(lock)then closed=false end end
 if not ok or not closed then return {ok=false,code=not ok and tostring(value):match(': busy$') and 'busy' or 'media_error'}end
 return value
end
local function references(editor)
 local draft=require('schoolbell.schedule_store').load(editor);assert(draft.ok,'draft_unavailable')
 local A=require('schoolbell.automatic_store');local active=A.decode(editor.read(A.name,A.max_bytes))
 local used={};local ids=require('schoolbell.media_ids')
 for _,id in ipairs(ids.references(draft.data))do used[id]=true end
 if active.plan then for _,id in ipairs(ids.references(active.plan))do used[id]=true end end
 return used,active
end
-- UI hints only: read atomically published files, never validate calendars or hash
-- entire plans on the hot listing path. remove() rechecks authoritative state.
local function usage_hint()
 local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store')
 local root=A.root or '/etc/schoolbell-editor';local fs=require('nixio.fs')
 local function read(name,maximum)
  local f=io.open(root..'/'..name,'rb')
  if not f then assert(not fs.lstat or not fs.lstat(root..'/'..name),'unreadable');return nil end
  local raw=f:read(maximum+1);f:close();assert(raw and #raw<=maximum,'size');return C.decode(raw)
 end
 local used={};local ids=require('schoolbell.media_ids')
 local function add(plan)
  assert(type(plan)=='table' and type(plan.schedules)=='table','plan')
  for _,id in ipairs(ids.references(plan))do used[id]=true end
 end
 local draft=read('current.json',S.file_bytes)
 if draft then add(draft.data)else assert(not fs.lstat or not fs.lstat(root..'/previous.json'),'draft_missing')end
 local active=read(A.name or 'automatic.json',A.max_bytes or 16384)
 if active then assert(type(active.data)=='table','active');if active.data.plan then add(active.data.plan)end end
 return used
end
local function listed(lib)
 local result=lib.list();local has_user=false
 for _,v in ipairs(result.slots)do if v.source=='user'then has_user=true end end
 if has_user then
  local known,used=pcall(usage_hint)
  for _,v in ipairs(result.slots)do if v.source=='user'then v.in_use=not known or used[v.id]==true end end
 end
 return result
end
local function inspect(read_catalog)
 local fs=require('schoolbell.media_fs')
 local editor=require('schoolbell.automatic_store').root
 local function available(view)
  return not view.stat('restore.pending') and not view.stat('import.pending')
 end
 local ok,result=pcall(function()
  local guard=fs.inspect(editor)
  local view=fs.inspect(L.root)
  local lib=L.open(view,L.root,function()return true end,true)
  for attempt=1,2 do
   local before=view.read('current.json',16384)
   local read,value=pcall(read_catalog,lib)
   if before==view.read('current.json',16384) and available(guard) then
    if read then return value end
    if attempt==2 then error(value) end
   end
  end
  return {ok=false,code='busy'}
 end)
 return ok and result or {ok=false,code='media_error'}
end
function M.list()return inspect(listed)end
function M.remove(args)
 if not L.editable(args.id)or not C.integer(args.generation,0,2147483646)or not C.hex(args.operation,32)then return {ok=false,code='invalid'}end
 return session(function(lib,fs,retain,editor)
  local used,active=references(editor)
  if active.enabled then return {ok=false,code='automatic_enabled'}end
  if used[args.id]then return {ok=false,code='in_use'}end
  local result=lib.remove(args.id,args.generation,args.operation)
  return {ok=result.status=='saved',code=result.status,generation=result.generation,operation_id=result.operation_id}
 end,true)
end
function M.rename(args)
 if not L.editable(args.id) or not L.valid_title(args.title)
  or not C.integer(args.generation,0,2147483646) or not C.hex(args.operation,32)then return {ok=false,code='invalid'}end
 return session(function(lib)
  local A=require('schoolbell.automatic_store');if A.decode(A.raw()).enabled then return {ok=false,code='automatic_enabled'}end
  local result=lib.rename(args.id,args.title,args.generation,args.operation)
  return {ok=result.status=='saved',code=result.status,generation=result.generation,operation_id=result.operation_id}
 end,true)
end
function M.lookup(op)
 if not C.hex(op,32)then return {ok=false,code='invalid'}end
 return inspect(function(lib)local v=lib.lookup(op);v.ok=true;return v end)
end
function M.resolve(id)
 assert(not require('nixio.fs').lstat or not require('nixio.fs').lstat((require('schoolbell.automatic_store').root or '/etc/schoolbell-editor')..'/import.pending'),'import_pending')
 -- Called by the player ONLY while it owns the shared gate.
 local fs=require('schoolbell.media_fs').new(L.root);local lib
 local ok,path,meta=pcall(function()lib=L.open(fs,L.root,function()return true end);return lib.resolve(id)end)
 if lib then lib.close()else fs.close()end
 assert(ok,path);return path,meta
end
function M.plan_ready(plan)
 if require('nixio.fs').lstat and require('nixio.fs').lstat((require('schoolbell.automatic_store').root or '/etc/schoolbell-editor')..'/import.pending')then return false end
 local fs=require('schoolbell.media_fs').new(L.root);local lib
 local ok,ready=pcall(function()
  lib=L.open(fs,L.root,function()return true end);local available={}
  for _,v in ipairs(lib.list().slots)do if v.source~='empty'then available[v.id]=true end end
  local used={}
  if plan.mode=='fixed' then
   used[plan.fixed_schedule or 'quiet']=true
  else
   local selected=require('schoolbell.schedule_store').selected_plan(plan)
   if not selected then return false end
   for i,id in ipairs(selected.schedule_ids)do
    if selected.days:find(string.char(64+i),1,true)then used[id]=true end
   end
  end
  for _,schedule in ipairs(plan.schedules)do for _,row in ipairs(schedule.rows)do
   if used[schedule.id] and row.enabled and (not available[row.media] or (row.pre and not available[plan.pre_media]))then return false end
  end end
  return true
 end)
 if lib then lib.close()else fs.close()end
 return ok and ready
end
function M.decode(path,retain)
 local n=require('nixio');local player=require('schoolbell.sound_test')
 local result=player.run({ready=function()return true end,acquire=function()return true end,release=function()return true end,
  limit=100,spawn=function()
   local pid=n.fork();if pid==0 then
    local f=n.open('/dev/null','r+');if not f then os.exit(126)end
    if not n.dup(f,n.stdin)or not n.dup(f,n.stdout)or not n.dup(f,n.stderr)then os.exit(126)end;f:close()
    n.exec('/usr/bin/madplay','--no-tty-control','-q','-o','null:/dev/null',path);os.exit(127)
   end;return pid
  end,wait=function(pid)return n.waitpid(pid,'nohang')end,kill=function(pid)return n.kill(pid,9)end,
  sleep=function()n.nanosleep(0,100000000)end})
 if result.state=='recovery_required'then retain()end
 assert(result.ok,'decoder failed')
end
function M.upload(args,source)
 if not L.valid_title(args.title or args.name) or not (args.id=='new' or L.editable(args.id)) or type(args.name)~='string' or #args.name<1 or #args.name>96 or args.name:find('[%c]')
  or not C.integer(args.generation,0,2147483646) or not C.hex(args.operation,32) or not C.integer(args.size,1,L.max_upload_bytes)then return {ok=false,code='invalid'}end
 return session(function(lib,fs,retain,editor)
  local A=require('schoolbell.automatic_store');if A.decode(A.raw()).enabled then return {ok=false,code='automatic_enabled'}end
  local listing=lib.list();if args.id=='new'then
   args.id='user_'..args.operation
   for _,v in ipairs(listing.slots)do if v.id==args.id then return {ok=false,code='conflict'}end end
   local S=require('schoolbell.schedule_store');local d=S.load(editor);if not d.ok then return {ok=false,code='busy'}end
   for _,id in ipairs(require('schoolbell.media_ids').references(d.data))do if id==args.id then return {ok=false,code='conflict'}end end
  end
  if listing.generation~=args.generation then return {ok=false,code='conflict'}end
  local free,capacity=fs.space();if free<2*args.size+65536+math.max(524288,math.ceil(capacity/10))then return {ok=false,code='space'}end
  -- An earlier failed request cannot still own this gate. Remove only its staging file.
  if fs.stat('upload.part')then fs.unlink('upload.part');fs.sync('')end
  local path=L.root..'/upload.part';local file=assert(io.open(path,'wb'))
  local uncertain=false
  local ok,result=protect(function()
   local bytes=0
   while true do local chunk,err=source();assert(not err,'upload interrupted');if not chunk then break end
    assert(type(chunk)=='string' and #chunk>0 and #chunk<=16384,'chunk');bytes=bytes+#chunk
    assert(bytes<=args.size,'upload too large');assert(file:write(chunk),'write')
   end
   assert(file:close());file=nil;assert(bytes==args.size,'upload truncated');fs.sync('upload.part')
   local audio=require('schoolbell.mp3').inspect(path);M.decode(path,function()uncertain=true;retain()end)
   assert(not A.decode(A.raw()).enabled,'automatic changed')
   local value=lib.replace(args.id,args.name,args.generation,args.operation,path,audio,args.title)
   return {ok=value.status=='saved',code=value.status,generation=value.generation,operation_id=value.operation_id,revision=value.revision,cleanup=value.cleanup,media_id=args.id}
  end)
  if file then file:close()end
  -- Preserve evidence when outcome of a decoder process is uncertain.
  if not uncertain and fs.stat('upload.part')then fs.unlink('upload.part');fs.sync('')end
  if not ok then return {ok=false,code='rejected'}end
  return result
 end,true)
end
function M.sample(id,write,ready)
 if not L.valid(id)then return {ok=false,code='invalid'}end
 -- Objects are immutable. Once opened, the descriptor pins the selected bytes
 -- even if another request replaces the melody or removes the directory entry.
 for attempt=1,2 do
  local path,size=L.bundled(id)
  local selected
  if path then
   local ok=pcall(require('schoolbell.media_fs').inspect,require('schoolbell.automatic_store').root)
   if not ok then return {ok=false,code='media_error'} end
   selected={ok=true,path=path,size=size}
  else
   selected=inspect(function(lib)
    local source,slot=lib.resolve(id)
    return {ok=true,path=source,size=slot.size_bytes}
   end)
  end
  if not selected.ok then return selected end
  local f=io.open(selected.path,'rb')
  if f then
   local ok=protect(function()
    assert(f:seek('end')==selected.size and f:seek('set',0)==0,'size')
    if ready and not ready() then return end
    while true do local chunk=f:read(16384);if not chunk then break end;write(chunk)end
   end)
   local closed=f:close()
   if ok and closed then return {ok=true}end
   return {ok=false,code='media_error'}
  end
 end
 return {ok=false,code='media_error'}
end
return M
