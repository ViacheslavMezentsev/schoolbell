local M=require('schoolbell.device_identity')
local function gpio(a,b)return ' gpio-41 ( |sw1 ) in '..a..'    \n gpio-42 ( |sw2 ) in '..b..'    \n'end
local values={['/tmp/sysinfo/board_name']='tplink,tl-mr3020-v3',['/sys/kernel/debug/gpio']=gpio('hi','hi')}
local interfaces={{name='lo',family='inet',addr='127.0.0.1'},{name='br-lan',family='inet',addr='192.0.2.1'},{name='wan',family='inet',addr='198.51.100.2'}}
local h={read=function(p,n)assert(n<=16384);return values[p]end,interfaces=function()return interfaces end}
for _,row in ipairs({{'lo','hi','3G/4G'},{'hi','lo','WISP'},{'hi','hi','AP'}})do values['/sys/kernel/debug/gpio']=gpio(row[1],row[2]);assert(M.read(nil,h).position==row[3])end
for _,bad in ipairs({gpio('lo','lo'),gpio('bad','hi'),gpio('hi','hi')..gpio('hi','hi'),gpio('hi','hi'):gsub('sw1','wrong'),string.rep('x',16385)})do
 values['/sys/kernel/debug/gpio']=bad;values['/tmp/switch_position']='ap';assert(M.read(nil,h).switch_state=='unknown')
end
values['/sys/kernel/debug/gpio']=gpio('hi','hi')
assert(M.read('198.51.100.2',h).ip=='198.51.100.2')
assert(M.read('evil.example',h).ip=='192.0.2.1')
values['/sys/kernel/debug/gpio']='invalid';assert(M.read(nil,h).switch_state=='unknown')
values['/sys/kernel/debug/gpio']=nil;assert(M.read(nil,h).position==nil)
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
