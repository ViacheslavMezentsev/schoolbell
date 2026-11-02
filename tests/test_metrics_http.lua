package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local method='GET';local status,out;local calls=0
package.loaded['luci.http']={getenv=function()return method end,status=function(v)status=v end,header=function(k,v)assert(k=='Cache-Control'and v=='no-store')end,prepare_content=function()end,write=function()end}
package.loaded['schoolbell.schedule_store']={}
package.loaded['schoolbell.media_codec']={encode=function(v)out=v;return '{}'end}
package.loaded['schoolbell.bell_metrics']={request=function(root)assert(root=='/etc/schoolbell-editor');calls=calls+1;return {ok=true,days={}}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
local m=luci.controller.schoolbell_test
m.metrics();assert(calls==1 and out.ok)
for _,v in ipairs({'POST','PUT','DELETE'})do method=v;status=nil;m.metrics();assert(status==405 and calls==1)end
print('PASS metrics HTTP: read-only GET, inherited admin route, mutation methods refused')
