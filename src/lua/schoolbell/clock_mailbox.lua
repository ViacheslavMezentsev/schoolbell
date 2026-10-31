-- One bounded private request and result. CGI submits; only the worker executes.
local C=require('schoolbell.media_codec');local M={}
local function hex(s,n)return type(s)=='string' and #s==n and s:match('^[0-9a-f]+$')end
function M.valid(q)
 if type(q)~='table' or not hex(q.id,32) or not hex(q.owner,64)then return false end
 for k in pairs(q)do if not ({id=true,owner=true,action=true,challenge=true,ack=true,enforced=true,revision=true,generation=true,epoch=true})[k]then return false end end
 if q.action=='set_prepare' or q.action=='set_time'then
  if not require('schoolbell.clock_set').epoch(q.epoch) or q.revision~=nil or q.generation~=nil or q.enforced~=nil then return false end
  if q.action=='set_prepare'then return q.challenge==nil and q.ack==nil end
  return hex(q.challenge,32) and q.ack=='true'
 end
 if q.epoch~=nil then return false end
 if q.action=='resume'then return hex(q.revision,64) and type(q.generation)=='string' and q.generation:match('^[1-9][0-9]*$') and #q.generation<=10 and tonumber(q.generation)<=2147483647 and q.enforced==nil and q.challenge==nil and q.ack==nil end
 if q.generation~=nil then return false end
 if q.action=='enable'then return hex(q.revision,64) and q.enforced==nil and q.challenge==nil and q.ack==nil end
 if q.revision~=nil then return false end
 if q.action=='prepare'then return q.challenge==nil and q.ack==nil and q.enforced==nil end
 if q.action=='confirm'then return hex(q.challenge,32) and (q.ack=='true' or q.ack=='false') and q.enforced==nil end
 return q.action=='policy' and (q.enforced=='true' or q.enforced=='false') and q.challenge==nil and q.ack==nil
end
function M.new(open,now,observer)
 local api={}
 local function measure(fs,event,value)
  if not observer then return end
  local ok=pcall(observer,fs,event,value)
  if not ok then pcall(function()if fs.stat('metrics.json')then fs.unlink('metrics.json')end end)end
 end
 local function run(fn)
  local fs;local ok,result=pcall(function()fs=open();return fn(fs)end)
  if fs then local closed=pcall(fs.close);if not closed then return {ok=false,code='mailbox_storage'}end end
  if ok then return result end
  -- Only failed lock acquisition is contention. Do not hide corrupt files/I/O as busy.
  if not fs and (result=='busy' or tostring(result):match(': busy$'))then return {ok=false,code='busy',accepted=false}end
  if tostring(result):match('package_maintenance$')then return {ok=false,code='package_maintenance',accepted=false}end
  return {ok=false,code='mailbox_storage'}
 end
 local function read(fs,name)local raw=fs.read(name,4096);return raw and C.decode(raw)end
 local function write(fs,name,v)
  if fs.stat('next')then fs.unlink('next')end
  local raw=C.encode(v);assert(#raw<=4096);fs.write('next',raw);fs.rename('next',name)
 end
 function api.submit(q)
  if not M.valid(q)then return {ok=false,code='invalid'}end
  return run(function(fs)
   local old=read(fs,'result.json');local pending=read(fs,'request.json')
   for _,v in pairs({old,pending})do
    if v.request.id==q.id then
     if C.encode(v.request)~=C.encode(q)then return {ok=false,code='conflict'}end
     return {ok=true,pending=true,id=q.id}
    end
   end
   if pending and now()-pending.at>=0 and now()-pending.at<=20 then return {ok=false,code='busy'}end
   local t=now();write(fs,'request.json',{request=q,at=math.floor(t),subms=math.floor((t%1)*1000)})
   if pending then measure(fs,'expired')end
   measure(fs,'queued')
   return {ok=true,pending=true,id=q.id}
  end)
 end
 function api.poll(id,owner)
  local result=run(function(fs)
   local v=read(fs,'result.json')
   if v and v.request.id==id and v.request.owner==owner then return v.result end
   return {ok=true,pending=true}
  end)
  -- The worker holds this lock through commit. A locked result is still pending.
  if result.code=='busy'then return {ok=true,pending=true,waiting='writer'}end
  return result
 end
 function api.process(handle)
  return run(function(fs)
   measure(fs,'tick')
   local q=read(fs,'request.json');if not q then return {ok=true}end
   local old=read(fs,'result.json');local result
   if old and old.request.id==q.request.id then result=old.result
   elseif not M.valid(q.request) or now()-q.at<0 or now()-q.at>15 then result={ok=false,code='expired'};measure(fs,'expired')
   else
    -- Consume before side effects: interruption is an unknown outcome, never replay.
    write(fs,'result.json',{request=q.request,result={ok=false,code='outcome_unknown'}})
    fs.unlink('request.json')
    measure(fs,'start',now()-q.at-(q.subms or 0)/1000)
    local ok,v=pcall(handle,q.request,{submitted_at=q.at+(q.subms or 0)/1000});result=ok and v or {ok=false,code='operation_failed'}
    measure(fs,'finish',type(result)=='table' and result.ok==true)
   end
   write(fs,'result.json',{request=q.request,result=result})
   if fs.stat('request.json')then fs.unlink('request.json')end
   return result
  end)
 end
 return api
end
function M.system(role)
 local root='/tmp/schoolbell-clock-control';local fs=require('nixio.fs')
 local function now()local f=assert(io.open('/proc/uptime','r'));local v=f:read(64);f:close();return assert(tonumber(v:match('^[%d.]+')))end
 return M.new(function()
  local pending='/etc/schoolbell-editor/package.pending'
  assert(not fs.lstat(pending),'package_maintenance')
  if not fs.lstat(root)then assert(fs.mkdir(root,700))end
  local handle=require('schoolbell.media_fs').new(root)
  -- Close the race with preinst after lock acquisition, before any mailbox mutation.
  if fs.lstat(pending)then handle.close();error('package_maintenance')end
  return handle
 end,now,require('schoolbell.queue_metrics').observer(now,role=='worker',tostring(math.floor(now()*1000))))
end
return M
