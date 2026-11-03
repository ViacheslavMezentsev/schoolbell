-- Session-bound, single-use confirmation; mailbox consumes commands before effects.
local M={}
function M.new(ports)
 local pending
 return function(q)
  if q.action=='system_prepare'then
   if q.target~='reset'and q.target~='reboot'then return {ok=false,code='invalid'}end
   pending={id=q.id,owner=q.owner,target=q.target,until_time=ports.now()+30}
   return {ok=true,challenge=q.id,target=q.target}
  end
  local target=q.action=='system_reset'and 'reset'or q.action=='system_reboot'and 'reboot'
  if not target or not pending or pending.id~=q.challenge or pending.owner~=q.owner or pending.target~=target or ports.now()>pending.until_time or q.ack~='true'then return {ok=false,code='stale_confirmation'}end
  pending=nil
  return ports.run(target,q.id)
 end
end
function M.system(now)
 local n=require('nixio');local nativefs=require('nixio.fs');local A=require('schoolbell.automatic_store')
 local reboot_until=0
 local function run(target,operation)
  if now()<reboot_until then return {ok=false,code='reboot_pending'}end
  local gate=require('schoolbell.sound_test').lock
  if not nativefs.mkdir(gate,700)then return {ok=false,code='busy'}end
  local editor
  local ok,result=pcall(function()
   assert(not nativefs.lstat(A.root..'/package.pending'),'package_maintenance')
   editor=require('schoolbell.media_fs').new(A.root,nil,target=='reset')
   if target=='reset'then
    local value=require('schoolbell.system_reset').apply(editor,operation)
    return value
   end
   A.change(editor,false,nil,{})
   local pid=n.fork();assert(pid,'fork')
   if pid==0 then
    local null=n.open('/dev/null','r+');if not null then os.exit(126)end
    if not n.dup(null,n.stdin)or not n.dup(null,n.stdout)or not n.dup(null,n.stderr)then os.exit(126)end;null:close()
    n.exec('/bin/sh','-c','sleep 3; exec /sbin/reboot');os.exit(127)
   end
   reboot_until=now()+15
   return {ok=true,state='reboot_requested',automatic_enabled=false}
  end)
  local closed=true;if editor then closed=pcall(editor.close)end
  if not nativefs.rmdir(gate)then closed=false end
  if not ok or not closed then return {ok=false,code='system_failed'}end
  return result
 end
 return M.new({now=now,run=run}),function()return now()<reboot_until end
end
return M
