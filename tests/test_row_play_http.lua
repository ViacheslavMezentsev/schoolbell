package.path='src/lua/?.lua;'..package.path
local id,output,allowed=nil,nil,true;local calls=0
package.loaded['luci.http']={formvalue=function()return id end,header=function()end,prepare_content=function()end,write_json=function(v)output=v end,write=function()end}
package.loaded['luci.dispatcher']={test_post_security=function()return allowed end}
package.loaded['schoolbell.schedule_store']={};package.loaded['schoolbell.media_codec']={encode=function(v)output=v;return '{}' end}
package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
package.loaded['schoolbell.sound_test']={system=function(v)calls=calls+1;return v end,run=function(v)return {ok=true,state='completed',id=v}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
local m=luci.controller.schoolbell_test
m.play();assert(output.id=='test')
for _,v in ipairs({'0','4','user1','user8','user9','user_deadbeef'})do id=v;m.play();assert(output.id==v)end
local before=calls
for _,v in ipairs({'../evil','user_zz','user0','5','',string.rep('a',1000)})do id=v;m.play();assert(output.state=='invalid' and calls==before)end
allowed=false;id='test';m.play();assert(calls==before)
print('PASS row play HTTP: default/selected IDs, rejected invalid IDs, CSRF gate, mocked sound only')
