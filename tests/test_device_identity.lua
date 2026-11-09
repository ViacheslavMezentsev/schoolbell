local M=require('schoolbell.device_identity')
local values={['/tmp/sysinfo/board_name']='tplink,tl-mr3020-v3',['/tmp/switch_position']='ap'}
local interfaces={{name='lo',family='inet',addr='127.0.0.1'},{name='br-lan',family='inet',addr='192.0.2.1'},{name='wan',family='inet',addr='198.51.100.2'}}
local h={read=function(p,n)assert(n<=96);return values[p]end,interfaces=function()return interfaces end}
for raw,label in pairs({ap='AP',wisp='WISP',['3g']='3G/4G'})do values['/tmp/switch_position']=raw;local v=M.read(nil,h);assert(v.position==label and v.ip=='192.0.2.1')end
assert(M.read('198.51.100.2',h).ip=='198.51.100.2')
assert(M.read('evil.example',h).ip=='192.0.2.1')
values['/tmp/switch_position']='invalid';assert(M.read(nil,h).switch_state=='unknown')
values['/tmp/switch_position']=nil;assert(M.read(nil,h).position==nil)
values['/tmp/sysinfo/board_name']='other';values['/tmp/switch_position']='ap';assert(M.read(nil,h).position==nil)
h.read=function()error('unreadable')end;assert(M.read(nil,h).ip=='192.0.2.1')
h.interfaces=function()error('unavailable')end;assert(M.read(nil,h).ip==nil)
h.interfaces=function()return interfaces end
h.read=function(path)return values[path]end
values['/tmp/sysinfo/model']='TP-Link TL-MR3020 v3'
values['/tmp/sysinfo/board_name']='tplink,tl-mr3020-v3'
local model=M.read(nil,h);assert(model.model=='TP-Link TL-MR3020 v3' and model.board_name=='tplink,tl-mr3020-v3')
values['/tmp/sysinfo/model']='  Other vendor board v7  ';assert(M.read(nil,h).model=='Other vendor board v7')
for _,bad in ipairs({'', '   ',string.rep('x',97),'bad\0name','bad\nname'})do
 values['/tmp/sysinfo/model']=bad;assert(M.read(nil,h).model==nil and M.read(nil,h).board_name=='tplink,tl-mr3020-v3')
end
values['/tmp/sysinfo/model']=string.rep('x',96);assert(#M.read(nil,h).model==96)
values['/tmp/sysinfo/model']=nil;assert(M.read(nil,h).model==nil)
h.read=function(path)if path=='/tmp/sysinfo/model' then error('denied')end;return values[path]end
assert(M.read(nil,h).board_name=='tplink,tl-mr3020-v3')
print('PASS model: exact system label, board fallback, unavailable/invalid/oversized; no revision inference')
print('PASS TC-200 header identity: all switch labels, unsupported/missing, current IP, no host-header trust and independent failures')
