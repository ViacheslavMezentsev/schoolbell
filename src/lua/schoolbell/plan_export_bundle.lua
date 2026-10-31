-- Build a complete private temporary file while caller holds editor/media locks.
local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store')
local A=require('schoolbell.automatic_store');local E=require('schoolbell.plan_export')
local Codec=require('schoolbell.plan_codec');local M={}
function M.build(editor,lib,work,env,selected,revision)
 assert(not editor.stat('restore.pending')and not editor.stat('import.pending'),'recovery_required')
 assert(not A.decode(editor.read(A.name,A.max_bytes)).enabled,'automatic_enabled')
 local saved=S.load(editor);assert(saved.ok,'draft');assert(saved.revision==revision,'conflict')
 local input={draft=saved.data,selected=selected,timezone=env.timezone(),exporter={name='schoolbell-device',version=env.version},media=C.decode('[]')}
 local slots={}
 for _,v in ipairs(lib.list().slots)do if v.source~='empty'then
  slots[v.id]=v;input.media[#input.media+1]={id=v.id,title=v.title,size_bytes=v.size_bytes,sha256=v.revision or string.rep('0',64)}
 end end
 -- Determine closure before opening any unreferenced audio object.
 local prepared=E.prepare(input);local manifest=Codec.manifest(prepared.manifest);local paths={};input.media=C.decode('[]')
 for _,v in ipairs(manifest.media)do
  local path=lib.resolve(v.id);local hash,size=env.inspect(path)
  assert(size==v.size_bytes and C.hex(hash,64),'dependency')
  if slots[v.id].source=='user'then assert(hash==slots[v.id].revision,'checksum')end
  paths[v.id]=path;input.media[#input.media+1]={id=v.id,title=v.title,size_bytes=size,sha256=hash}
 end
 prepared=E.prepare(input);local _,size=Codec.manifest(prepared.manifest)
 local free,total=work.space();assert(free>=2*size+131072+math.max(1048576,math.ceil(total/10)),'space')
 local open={};local scratch={};local function track(f)open[#open+1]=f;return f end
 local output=track(work.open_write('plan.sbp'));local count,serial=0,0
 local ok,result=pcall(function()
  local function source(slot)
   local f=track(env.open(paths[slot]));return function()local chunk=f:read(16384);return chunk end
  end
  local function hash_factory()
   serial=serial+1;local name='hash-'..serial;scratch[#scratch+1]=name;local f=track(work.open_write(name))
   return {update=function(_,chunk)assert(f:write(chunk),'storage_unavailable')end,finish=function()
    assert(f:close(),'storage_unavailable');local hash=work.hash(name);work.unlink(name);return hash
   end}
  end
  local bytes=E.encode(input,source,hash_factory,function(chunk)
   count=count+#chunk;assert(count<=size and #chunk<=16384,'size');assert(output:write(chunk),'storage_unavailable')
  end)
  assert(bytes==size and count==size,'size');assert(output:close(),'storage_unavailable')
  return {size=size,sha256=work.hash('plan.sbp'),revision=saved.revision}
 end)
 for _,f in ipairs(open)do pcall(function()f:close()end)end
 for _,name in ipairs(scratch)do if work.stat(name)then work.unlink(name)end end
 if not ok then if work.stat('plan.sbp')then work.unlink('plan.sbp')end;error(result,0)end
 return result
end
return M
