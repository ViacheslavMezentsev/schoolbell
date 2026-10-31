-- LuCI system port. Own operation lock, then short player/editor/media sessions.
local C=require('schoolbell.media_codec');local F=require('schoolbell.media_fs')
local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local Codec=require('schoolbell.plan_codec');local Preview=require('schoolbell.plan_preview')
local Admission=require('schoolbell.plan_admission');local Import=require('schoolbell.plan_import')
local n,fs=require('nixio'),require('nixio.fs');local protect=require('luci.util').copcall
local M={root='/tmp/schoolbell-plan-import'}
local function mono()local f=assert(io.open('/proc/uptime'));local v=tonumber(f:read('*l'):match('^[%d.]+'));f:close();return math.floor(assert(v))end
local function boot()local f=assert(io.open('/proc/sys/kernel/random/boot_id'));local v=f:read(64);f:close();return v end
local function random()local f=assert(io.open('/dev/urandom','rb'));local s=assert(f:read(32));f:close();assert(#s==32);return(s:gsub('.',function(c)return string.format('%02x',c:byte())end))end
local function timezone()
 local b=require('schoolbell.timezone').system();local ok,value=pcall(function()
  local state=b.read();local zones=b.zones();assert(not state.pending and zones[state.zone]==state.posix and b.matches(state.posix),'timezone')
  return {name=state.zone,posix=state.posix}
 end);b.close();assert(ok,value);return value
end
local function inventory(lib)
 local out=C.decode('[]')
 for _,v in ipairs(lib.list().slots)do if v.source~='empty'then
  local path=lib.resolve(v.id);local f=assert(io.popen('sha256sum '..path,'r'));local hash=assert(f:read('*l')):match('^[0-9a-f]+');assert(f:close());assert(C.hex(hash,64),'dependency')
  out[#out+1]={id=v.id,sha256=hash,size_bytes=v.size_bytes}
 end end
 return out
end
local function state(fn)
 local gate=require('schoolbell.sound_test').lock
 assert(fs.mkdir(gate,700),'busy')
 local ed,media,api
 local ok,result,proof=protect(function()
  ed=F.new(A.root,nil,'import');media=F.new(L.root)
  api=Import.new(ed,media,L.root,{timezone=timezone,inventory=inventory,preview=Preview.preview,monotonic=mono,boot=boot,random=random})
  return fn(api)
 end)
 local closed=true
 if api then closed=pcall(api.close)else if media then closed=pcall(media.close)and closed end;if ed then closed=pcall(ed.close)and closed end end
 assert(closed,'storage_unavailable')
 assert(fs.rmdir(gate),'storage_unavailable');assert(ok,result);return result,proof
end
local function read(work)
 local raw=work.read('operation.json',65536);return raw and C.decode(raw)
end
local function write(work,v)
 if work.stat('operation-next.json')then work.unlink('operation-next.json')end
 local raw=C.encode(v);assert(#raw<=65536,'size');work.write('operation-next.json',raw);work.rename('operation-next.json','operation.json')
end
local function clean(work)
 for _,name in ipairs(work.list(''))do
  if name~='.lock'then assert(name=='operation.json'or name=='operation-next.json'or name=='archive.sbp'or name=='calendar.json'or C.hex(name,64),'foreign file');work.unlink(name)end
 end
end
local function failed(id,why)
 local code='storage_unavailable';local text=tostring(why)
 for _,v in ipairs({'not_found','busy','format','size','checksum','dependency','timezone','space','expired','invalid_state','automatic_enabled','conflict','recovery_required'})do if text==v or text:match(': '..v..'$')then code=v;break end end
 return {ok=false,operation_id=id,state=code=='recovery_required'and'recovery_required'or'not_found',code=code}
end
function M.request(action,id,args,pump,request_size)
 if not C.hex(id,32)then return failed(id,'format')end
 if action=='status'then
  -- Read durable result first; a reboot may have removed the temporary upload.
  local ok,v=pcall(state,function(api)return api.status(id)end)
  if not ok then return failed(id,v)end
  if v.state~='not_found'or v.code=='busy'then return v end
  if not fs.stat(M.root)then return v end
 elseif action=='commit'then
  local ok,v=pcall(state,function(api)return api.status(id)end);if not ok then return failed(id,v)end
  if v.state~='not_found' or v.code=='busy'then return v end
 elseif action=='resume'then
  local ok,v=pcall(state,function(api)return api.resume(id)end);return ok and v or failed(id,v)
 end
 if not fs.stat(M.root)then if action~='upload'then return failed(id,'not_found')end;assert(fs.mkdir(M.root,700))end
 local ok,work=pcall(F.new,M.root);if not ok then return failed(id,work)end
 local good,value=protect(function()
  local record=read(work)
  if action=='upload'then
   local durable=state(function(api)return api.status(id)end)
   if durable.state~='not_found'or durable.code=='busy'then return durable end
   if record and record.operation_id==id then return failed(id,'invalid_state')end
   if record and record.boot==boot()and mono()-record.touched<1800 and record.state~='cancelled'and record.state~='rejected'and record.state~='committed'then return failed(id,'busy')end
   clean(work)
   record={operation_id=id,state='receiving',boot=boot(),touched=mono(),tmp_required=2*request_size+131072};write(work,record)
   local free,total=work.space();assert(free>=2*request_size+131072+math.max(1048576,math.ceil(total/10)),'space')
   local f=work.open_write('archive.sbp');local count=0;local start,last=mono(),mono()
   local loaded,err=protect(function()pump(function(chunk)
    local now=mono();assert(now>=last and now-last<=60 and now-start<=300,'expired');last=now
    assert(type(chunk)=='string'and #chunk<=16384,'size');count=count+#chunk;assert(count<=Codec.maximum,'size');assert(f:write(chunk),'storage_unavailable')
   end)end)
   local closed=f:close();if not loaded or not closed then record.state='rejected';write(work,record);error(err or 'storage_unavailable')end
   assert(count>0,'size')
   -- Admission never opens an audio device; MP3 is decoded to null output.
   local admitted=Admission.validate(work,{work_root=M.root,inspect=require('schoolbell.mp3').inspect,decode=function(path)
    local gate=require('schoolbell.sound_test').lock;assert(fs.mkdir(gate,700),'busy');local keep=false
    local ok,err=pcall(require('schoolbell.media_web').decode,path,function()keep=true end)
    if not keep then assert(fs.rmdir(gate))end;assert(ok,err)
   end})
   assert(mono()-start<=300,'expired')
   record.state='validated';record.admitted=admitted;record.touched=mono();write(work,record)
   return {ok=true,operation_id=id,state='validated',code='ok',plans=C.decode(admitted.calendar).plans,schedules=C.decode(admitted.calendar).schedules}
  end
  assert(record and record.operation_id==id,'not_found')
  if action=='status'then
   if record.boot~=boot()or mono()-record.touched>1800 then return {ok=true,operation_id=id,state='expired',code='expired'}end
   local value={ok=true,operation_id=id,state=record.state,code='ok'}
   if record.admitted then local calendar=C.decode(record.admitted.calendar);value.plans=calendar.plans;value.schedules=calendar.schedules end
   return value
  end
  if action=='cancel'then
   local durable=state(function(api)return api.status(id)end);if durable.state~='not_found'then return durable end
   clean(work);write(work,{operation_id=id,state='cancelled',boot=boot(),touched=mono()});return {ok=true,operation_id=id,state='cancelled',code='ok'}
  end
  assert(record.boot==boot()and mono()>=record.touched and mono()-record.touched<=1800,'expired')
  if action=='preview'then
   assert(record.state=='validated'or record.state=='preview','invalid_state')
   local v,proof=state(function(api)return api.preview(id,record.admitted,args.names)end)
   if proof then local free,total=work.space();local reserve=math.max(1048576,math.ceil(total/10));v.space.tmp={required=record.tmp_required,free=math.min(free,2147483647),reserve=math.min(reserve,2147483647),capped=free>2147483647 or reserve>2147483647}end
   assert(#C.encode(v)<=32768,'size')
   record.proof=proof;record.touched=mono();record.state=proof and 'preview'or'validated';write(work,record);return v
  end
  if action=='commit'then
   assert(record.state=='preview','invalid_state')
   local result=state(function(api)return api.commit(id,args.preview_token,record.proof,record.admitted)end)
   if result.state=='committed'then record.state='committed';record.proof=nil;record.admitted=nil;write(work,record)end
   return result
  end
  error('invalid_state')
 end)
 if not good and action=='upload'then pcall(function()local v=read(work);if v and v.operation_id==id then v.state='rejected';v.admitted=nil;write(work,v)end end)end
 local closed=pcall(work.close);return good and closed and value or failed(id,value)
end
return M
