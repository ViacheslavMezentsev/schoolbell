-- Private active snapshot, separate from the editable draft. No playback here.
local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store')
local M={root='/etc/schoolbell-editor',name='automatic.json',max_bytes=16384}
function M.decode(raw)
 if raw==nil then return {enabled=false,generation=0,watermark=0}end
 local envelope=assert(C.decode(raw),'json');local v=envelope.data
 assert(v and C.sha(C.encode(v))==envelope.checksum,'checksum')
 assert(type(v.enabled)=='boolean' and C.integer(v.generation,1,2147483647) and C.integer(v.watermark,0,2147483647),'state')
 if v.enabled or v.plan~=nil then
  assert(type(v.boot)=='string' and #v.boot<=64 and type(v.zone)=='string' and #v.zone<=256,'environment')
  local data,body=S.validate(C.encode(v.plan));assert(data and C.sha(body)==v.revision,'plan')
 elseif v.revision~=nil then error('orphan_revision')
 end
 return v
end
function M.raw()
 assert(not require('nixio.fs').lstat(M.root..'/import.pending'),'import_pending')
 assert(not require('nixio.fs').lstat(M.root..'/restore.pending'),'restore_pending')
 local path=M.root..'/'..M.name;local f=io.open(path,'rb')
 if not f then assert(not require('nixio.fs').lstat(path),'unreadable');return nil end
 local raw=f:read(M.max_bytes+1);f:close();assert(raw and #raw<=M.max_bytes,'size');return raw
end
local function write(fs,v)
 local body=C.encode(v);local raw=C.encode({data=v,checksum=C.sha(body)})
 assert(#raw<=M.max_bytes,'size')
 local free,total=fs.space();assert(free>=math.max(524288,math.ceil(total/10))+2*M.max_bytes,'space')
 if fs.stat('automatic-next.json')then fs.unlink('automatic-next.json')end
 fs.write('automatic-next.json',raw);fs.sync('automatic-next.json')
 fs.rename('automatic-next.json',M.name);fs.sync('')
 assert(fs.read(M.name,M.max_bytes)==raw,'verify');return v,raw
end
function M.change(fs,enabled,revision,env)
 local current=M.decode(fs.read(M.name,M.max_bytes))
 assert(current.generation<2147483647,'generation')
 local v={enabled=enabled,generation=current.generation+1,watermark=enabled and math.max(current.watermark,env.now) or current.watermark}
 if enabled then
  local draft=S.load(fs);assert(draft.ok and draft.revision~='empty' and draft.revision==revision,'draft_conflict')
  assert(env.now>=1577836800 and env.now<2145916800,'clock_range')
  local events,why=require('schoolbell.automatic').events(draft.data,env.date,env.resolve)
  assert(events,why)
  v.plan=draft.data;v.revision=draft.revision;v.boot=env.boot;v.zone=env.zone
 elseif current.plan then
  v.plan=current.plan;v.revision=current.revision;v.boot=current.boot;v.zone=current.zone
 end
 return write(fs,v)
end
-- Resume the retained applied snapshot under the same storage lock. Never load draft.
function M.resume(fs,revision,generation,env,admit)
 local current=M.decode(fs.read(M.name,M.max_bytes))
 assert(current.plan and not current.enabled,'no_stopped_plan')
 assert(current.revision==revision and current.generation==generation,'active_conflict')
 assert(current.generation<2147483647,'generation')
 assert(env.now>=1577836800 and env.now<2145916800,'clock_range')
 local events,why=require('schoolbell.automatic').events(current.plan,env.date,env.resolve)
 assert(events,why)
 assert(admit(current.plan),'resume_not_ready')
 local v={enabled=true,generation=current.generation+1,plan=current.plan,revision=current.revision,
  boot=env.boot,zone=env.zone,watermark=math.max(current.watermark,env.now)}
 return write(fs,v)
end
function M.advance(fs,generation,now)
 local raw=fs.read(M.name,M.max_bytes);local v=M.decode(raw)
 assert(v.enabled and v.generation==generation,'stale_checkpoint')
 if now<=v.watermark then return v,raw end
 v.watermark=now;return write(fs,v)
end
function M.claim(fs,generation,utc,now)
 local v=M.decode(fs.read(M.name,M.max_bytes))
 assert(v.enabled and v.generation==generation and utc>v.watermark,'stale_claim')
 assert(now>=utc,'expired')
 v.watermark=math.max(now,utc);return write(fs,v)
end
function M.transaction(operation,...)
 local args={...};local fs
 local ok,value,raw=pcall(function()fs=require('schoolbell.media_fs').new(M.root);return operation(fs,unpack(args))end)
 local closed=true;if fs then closed=pcall(fs.close)end
 if not ok or not closed then return {ok=false,code='automatic_storage',detail=tostring(value):sub(1,160)}end
 return {ok=true,state=value,raw=raw}
end
function M.environment()
 local function read(p,max)local f=assert(io.open(p,'rb'));local v=f:read(max+1);f:close();assert(v and #v<=max);return v end
 return {now=os.time(),date=os.date('%Y-%m-%d'),boot=read('/proc/sys/kernel/random/boot_id',64),zone=read('/tmp/TZ',256)}
end
return M
