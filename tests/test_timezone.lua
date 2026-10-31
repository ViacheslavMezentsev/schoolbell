local M=require('schoolbell.timezone')
local function fixture()
 local state={zone='UTC',posix='UTC',revision='r1',pending=false};local current='UTC';local calls={commit=0,apply=0}
 local b={read=function()return state end,zones=function()return {UTC='UTC',['Asia/Yekaterinburg']='<+05>-5'}end,
 matches=function(p)return p==current end}
 b.commit=function(zone,posix,revision)calls.commit=calls.commit+1;assert(revision==state.revision);state.zone=zone;state.posix=posix;state.revision='r2';return true end
 b.apply=function()calls.apply=calls.apply+1;current=state.posix;return true end
 return b,state,calls
end
local b,s,c=fixture();assert(M.request(b).ok and c.commit==0 and c.apply==0)
assert(M.request(b,'UTC','r1').unchanged and c.commit==0)
assert(M.request(b,'$(reboot)','r1').code=='invalid_zone' and c.commit==0)
assert(M.request(b,'Asia/Yekaterinburg','old').code=='conflict' and c.commit==0)
s.pending=true;assert(M.request(b,'Asia/Yekaterinburg','r1').code=='pending_changes');s.pending=false
assert(M.request(b,'Asia/Yekaterinburg','r1').ok and c.commit==1 and c.apply==1)
b,s,c=fixture();b.apply=function()return false end
local result=M.request(b,'Asia/Yekaterinburg','r1');assert(not result.ok and result.saved and result.code=='apply_failed' and s.zone=='Asia/Yekaterinburg')
b,s,c=fixture();b.commit=function()return false end;assert(M.request(b,'Asia/Yekaterinburg','r1').code=='save_uncertain' and c.apply==0)
b,s,c=fixture();b.read=function()error('busy')end;assert(M.request(b).code=='unavailable')
print('PASS timezone: read-only GET, no-op, whitelist, stale revision, pending UCI, commit/apply, uncertain failures')
local method,length,status,security='POST','999999',nil,0
package.loaded['luci.http']={getenv=function(k)if k=='REQUEST_METHOD'then return method elseif k=='CONTENT_LENGTH'then return length else return 'application/x-www-form-urlencoded' end end,status=function(v)status=v end,formvalue=function()error('must not decode')end}
package.loaded['luci.dispatcher']={test_post_security=function()security=security+1;return false end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
luci.controller.schoolbell_test.timezone();assert(status==413 and security==0)
length='100';luci.controller.schoolbell_test.timezone();assert(security==1)
method='PUT';luci.controller.schoolbell_test.timezone();assert(status==405 and security==1)
print('PASS timezone HTTP: request bounds, CSRF, method guard')

local original=io.popen;local payload
io.popen=function(command)assert(command:find('zonename',1,true));return {read=function()return 'Asia/Yekaterinburg\n'end,close=function()return true end}end
package.loaded['luci.http']={getenv=function()return 'GET'end,header=function()end,prepare_content=function()end,write=function(s)payload=s end}
luci.controller.schoolbell_test.clock();io.popen=original
local value=assert(require('schoolbell.media_codec').decode(payload));assert(value.zone=='Asia/Yekaterinburg' and type(value.epoch)=='number')
print('PASS clock: configured timezone name in public clock response')
