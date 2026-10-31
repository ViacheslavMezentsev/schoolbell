-- Executor-owned admission gate. No audio, NTP or clock-setting operations.
local Trust=require('schoolbell.clock_trust')
local M={}
function M.new(open,options)
 options=options or {};assert(type(open)=='function','clock ports factory')
 local enforced=options.enforced;if enforced==nil then enforced=true end
 assert(type(enforced)=='boolean','enforced must be boolean')
 local model,fault,armed
 local function reset()
  model=nil;fault=nil;armed=false
  if enforced then
   local ok,value=pcall(function()return Trust.new(open(),options)end)
   if ok then model=value else fault='clock_unavailable'end
  end
 end
 reset();local api={}
 local function status()
  local s=model and model.status() or {state=enforced and 'review_required' or 'unchecked',reason=fault or 'control_disabled',accuracy_known=false}
  s.enforced=enforced;s.automatic_permitted=armed and (not enforced or (s.state=='confirmed' and s.enabled==true)) or false
  return s
 end
 function api.invalidate()reset()end -- revoke pre-step trust even for sub-threshold corrections
 function api.status()return status()end
 function api.observe(checkpoint)
  if model then model.observe(checkpoint);if not model.status().enabled then armed=false end end
  return status()
 end
 function api.configure(value)
  if type(value)~='boolean'then return {ok=false,code='invalid_policy'}end
  if value~=enforced then enforced=value;reset()end
  return {ok=true,enforced=enforced}
 end
 function api.request_confirmation()
  if not model then return nil,enforced and 'clock_unavailable' or 'control_disabled'end
  return model.request_confirmation()
 end
 function api.confirm(token,ack)
  armed=false
  if not model then return {ok=false,code=enforced and 'clock_unavailable' or 'control_disabled'}end
  return model.confirm(token,ack)
 end
 function api.enable()
  armed=false
  if enforced then
   if not model then return {ok=false,code='clock_unavailable'}end
   local result=model.enable();if not result.ok then return result end
  end
  armed=true;return {ok=true}
 end
 function api.disable()armed=false;if model then model.disable()end end
 function api.admit()
  if enforced then
   if not model or not model.admit()then armed=false;return false end
  end
  return armed
 end
 return api
end
-- Explicit local policy, deliberately separate from portable school backups.
-- Native dependency and an authenticated confirmation UI are deployment prerequisites.
function M.system()
 local C=require('schoolbell.media_codec');local fs=require('nixio.fs')
 local policy=require('schoolbell.automatic_store').root..'/clock-policy.json'
 local function read_policy()
  assert(not fs.lstat(require('schoolbell.automatic_store').root..'/clock-policy.pending'),'policy interrupted')
  local st=fs.lstat(policy);if not st then return true end
  assert(st.type=='reg' and type(st.size)=='number' and st.size>=1 and st.size<=256,'policy file')
  local f=assert(io.open(policy,'rb'),'policy unreadable')
  local raw=f:read(257);local closed=f:close();assert(closed and raw and #raw==st.size and #raw<=256,'policy size')
  local v=C.decode(raw);C.fields(v,{'enforced'});assert(type(v.enforced)=='boolean','policy');return v.enforced
 end
 local ok,enforced=pcall(read_policy);if not ok then enforced=true end
 return M.new(function()
  assert(read_policy()==true,'invalid policy')
  local native=require('schoolbell.clock_linux')
  local root=require('schoolbell.automatic_store').root -- provisioned private editor directory
  local observer=tostring({})
  return require('schoolbell.clock_system').new(root,function()
   local e=require('schoolbell.automatic_store').environment()
   return C.sha(e.boot..'\0'..e.zone)..observer
  end,native)
 end,{enforced=enforced})
end
return M
