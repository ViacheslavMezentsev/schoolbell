-- TC-134: maintenance must reject queued writes on both sides of lock acquisition.
local Mailbox=require('schoolbell.clock_mailbox')
for _,race in ipairs({false,true})do
 local checks,opened,closed=0,0,0
 package.loaded['nixio.fs']={lstat=function(path)
  if path=='/etc/schoolbell-editor/package.pending'then checks=checks+1;return (not race or checks>1)and {type='reg'} or nil end
  return {type='dir'}
 end}
 package.loaded['schoolbell.media_fs']={new=function()opened=opened+1;return {close=function()closed=closed+1 end}end}
 local result=Mailbox.system().submit({id=string.rep('a',32),owner=string.rep('b',64),action='enable',revision=string.rep('c',64)})
 assert(not result.ok and result.code=='package_maintenance' and result.accepted==false)
 assert(opened==(race and 1 or 0)and opened==closed)
end
print('PASS package maintenance rejects mailbox before/after lock; no stale enable admission')
