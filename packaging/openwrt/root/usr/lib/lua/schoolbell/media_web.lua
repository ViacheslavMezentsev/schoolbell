-- Engineering media gateway: same exclusive gate as the diagnostic player.
local M={}
-- LuCI request sources and response sinks may yield on Lua 5.1.
local protect=require('luci.util').copcall
local L=require('schoolbell.media_library');local C=require('schoolbell.media_codec')
local function session(fn)
 local n,fs=require('nixio'),require('nixio.fs');local lock=require('schoolbell.sound_test').lock
 if not fs.mkdir(lock,700)then return {ok=false,code='busy'}end
 local backend,library;local keep=false
 local ok,value=protect(function()
  local editor=require('schoolbell.automatic_store').root or '/etc/schoolbell-editor'
  assert(not fs.lstat or not fs.lstat(editor..'/import.pending'),'import_pending')
  assert(not fs.lstat or not fs.lstat(editor..'/restore.pending'),'restore_pending')
  backend=require('schoolbell.media_fs').new(L.root)
  library=L.open(backend,L.root,function()return true end)
  return fn(library,backend,function()keep=true end)
 end)
 local closed=true;if library then closed=pcall(library.close)elseif backend then closed=pcall(backend.close)end
 if not keep then if not fs.rmdir(lock)then closed=false end end
 if not ok or not closed then return {ok=false,code='media_error'}end
 return value
end
function M.list()return session(function(lib)return lib.list()end)end
function M.lookup(op)
 if not C.hex(op,32)then return {ok=false,code='invalid'}end
 return session(function(lib)local v=lib.lookup(op);v.ok=true;return v end)
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
  for _,schedule in ipairs(plan.schedules)do for _,row in ipairs(schedule.rows)do
   if row.enabled and (not available[row.media] or (row.pre and not available[plan.pre_media]))then return false end
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
 if (args.title~=nil and (type(args.title)~='string' or #args.title<1 or #args.title>96 or args.title:find('[%c]'))) or not (args.id=='new' or L.editable(args.id)) or type(args.name)~='string' or #args.name<1 or #args.name>96 or args.name:find('[%c]')
  or not C.integer(args.generation,0,2147483646) or not C.hex(args.operation,32) or not C.integer(args.size,1,524288)then return {ok=false,code='invalid'}end
 return session(function(lib,fs,retain)
  local A=require('schoolbell.automatic_store');if A.decode(A.raw()).enabled then return {ok=false,code='automatic_enabled'}end
  local listing=lib.list();if args.id=='new'then
   args.id='user_'..args.operation
   for _,v in ipairs(listing.slots)do if v.id==args.id then return {ok=false,code='conflict'}end end
   local S=require('schoolbell.schedule_store');local d=S.request(A.root or '/etc/schoolbell-editor','load');if not d.ok then return {ok=false,code='busy'}end
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
 end)
end
function M.sample(id,write)
 if not L.valid(id)then return {ok=false,code='invalid'}end
 return session(function(lib)
  local path=lib.resolve(id);local f=assert(io.open(path,'rb'))
  local ok,why=protect(function()while true do local chunk=f:read(16384);if not chunk then break end;write(chunk)end end)
  f:close();assert(ok,why);return {ok=true}
 end)
end
return M
