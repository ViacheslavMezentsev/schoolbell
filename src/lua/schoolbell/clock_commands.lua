-- Worker-owned confirmation tokens; no token survives a worker restart.
local M={}
function M.new(gate,ports)
 local challenge
 return function(q)
  if q.action=='enable' or q.action=='resume' then
   local allowed=gate.enable();if not allowed.ok then return allowed end
   if not gate.admit()then gate.disable();return {ok=false,code='clock_untrusted'}end
   local ok,result=pcall(function()if q.action=='resume'then return ports.resume(q.revision,tonumber(q.generation))end;return ports.enable(q.revision)end)
   gate.disable();if not ok then return {ok=false,code='operation_failed'}end;return result
  end
  if q.action=='prepare' then
   local value,why=gate.request_confirmation()
   if not value then return {ok=false,code=why}end
   challenge={id=q.id,owner=q.owner,token=value.token}
   return {ok=true,challenge=q.id,utc=math.floor(value.utc_ms/1000),rollback=value.requires_rollback_ack==true,zone=ports.zone(),local_time=ports.localtime and ports.localtime(math.floor(value.utc_ms/1000)) or nil}
  end
  if q.action=='confirm' then
   if not challenge or challenge.owner~=q.owner or challenge.id~=q.challenge then return {ok=false,code='stale_confirmation'}end
   local token=challenge.token;challenge=nil
   gate.disable()
   if not ports.stop()then return {ok=false,code='disable_failed'}end
   return gate.confirm(token,q.ack=='true')
  end
  if q.action=='policy' then
   challenge=nil;gate.disable()
   if not ports.stop()then return {ok=false,code='disable_failed'}end
   if not ports.policy(q.enforced=='true')then
    gate.configure(false);gate.configure(true)
    return {ok=false,code='policy_write_failed'}
   end
   gate.configure(false);gate.configure(q.enforced=='true')
   return {ok=true,enforced=q.enforced=='true'}
  end
  return {ok=false,code='invalid_action'}
 end
end
return M
