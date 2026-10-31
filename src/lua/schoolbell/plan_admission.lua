-- Bounded file admission for .sbp. Private work directory, no shell extraction.
local C=require('schoolbell.media_codec')
local Codec=require('schoolbell.plan_codec')
local M={maximum=Codec.maximum}
function M.receive(work,source,size,env)
 assert(C.integer(size,1,M.maximum),'size')
 assert(not work.stat('archive.sbp'),'invalid_state')
 local free,total=work.space();local reserve=math.max(1048576,math.ceil(total/10))
 -- Archive plus validated extracted audio coexist; reserve both before receiving.
 assert(free>=2*size+131072+reserve,'space')
 local f=work.open_write('archive.sbp');local received=0;local start=env.monotonic();local last=start
 local protect=env.protect or pcall
 local ok,why=protect(function()
  while true do
   local chunk,err=source();local now=env.monotonic()
   assert(now>=last and now-last<=60 and now-start<=300,'expired');last=now
   assert(not err,'format');if not chunk then break end
   assert(type(chunk)=='string'and #chunk>0 and #chunk<=16384,'size')
   received=received+#chunk;assert(received<=size,'size');assert(f:write(chunk),'storage_unavailable')
  end
  assert(received==size,'size')
 end)
 local closed=f:close();assert(ok and closed,why or 'storage_unavailable')
 return M.validate(work,env)
end
function M.validate(work,env)
 local st=assert(work.stat('archive.sbp'),'not_found');assert(st.size>0 and st.size<=M.maximum,'size')
 local input=work.open_read('archive.sbp');local out,path
 local function close()if out then local f=out;out=nil;assert(f:close(),'storage_unavailable')end end
 local ok,result=pcall(function()
  local decoded=Codec.decode(function()return input:read(16384)end,function()
   return {update=function()return true end,finish=function()close();return work.hash(path)end}
  end,function(name,chunk)
   local target=name=='calendar.json'and name or name:match('^media/([0-9a-f]+)%.mp3$')
   assert(target,'format')
   if target~=path then close();path=target;if work.stat(path)then work.unlink(path)end;out=work.open_write(path)end
   assert(out:write(chunk),'storage_unavailable')
  end)
  local h=work.open_read('archive.sbp');local header=h:read(82);local n=tonumber(header:sub(9,16));local raw=h:read(n);assert(h:close())
  local inventory=C.decode('[]')
  for _,v in ipairs(decoded.manifest.media)do if v.source=='bundled'then inventory[#inventory+1]={id=v.bundled_id,size_bytes=v.size_bytes,sha256=v.sha256}end end
  local check=require('schoolbell.plan_preview').preview(raw,decoded.calendar,{draft=require('schoolbell.schedule_store').empty(),timezone=decoded.manifest.timezone,media=inventory,operation_id=string.rep('0',32),automatic_enabled=false,dirty=false,target='device',names=C.decode('{"plans":{},"schedules":{}}')})
  assert(check.ok,'dependency')
  local objects={}
  for i=2,#decoded.manifest.files do
   local entry=decoded.manifest.files[i];local p=env.work_root..'/'..entry.sha256
   local audio=env.inspect(p);if env.decode then env.decode(p)end
   objects[entry.sha256]={path=p,size_bytes=entry.size_bytes,audio=audio}
  end
  return {manifest=decoded.manifest,manifest_raw=raw,calendar=decoded.calendar,archive_sha256=work.hash('archive.sbp'),objects=objects}
 end)
 local ci=input:close();local co=pcall(close);assert(ok and ci and co,result)
 return result
end
return M
