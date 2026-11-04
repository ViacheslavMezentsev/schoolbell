package.path='src/lua/?.lua;'..package.path
local id,output,allowed=nil,nil,true;local calls=0
package.loaded['luci.http']={formvalue=function()return id end,header=function()end,prepare_content=function()end,write_json=function(v)output=v end,write=function()end}
package.loaded['luci.dispatcher']={test_post_security=function()return allowed end}
package.loaded['schoolbell.schedule_store']={};package.loaded['schoolbell.media_codec']={encode=function(v)output=v;return '{}' end}
package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
package.loaded['schoolbell.sound_test']={system=function(v)calls=calls+1;return {id=v,spawn=function()return 1 end}end,run=function(v)assert(v.spawn()==1);return {ok=true,state='completed',id=v.id}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
package.loaded['schoolbell.controls']={snapshot=function()return {ok=true,confirm_play=false}end}
local m=luci.controller.schoolbell_test
m.play();assert(output.id=='test')
for _,v in ipairs({'0','4','user1','user8','user9','user_deadbeef'})do id=v;m.play();assert(output.id==v)end
local before=calls
for _,v in ipairs({'../evil','user_zz','user0','5','',string.rep('a',1000)})do id=v;m.play();assert(output.state=='invalid' and calls==before)end
package.loaded['schoolbell.controls'].snapshot=function()return {ok=true,confirm_play=true}end
id='test';m.play();assert(output.state=='confirmation_required' and calls==before)
local http=package.loaded['luci.http'];http.formvalue=function(k)return k=='confirmed' and 'true' or id end
m.play();assert(output.ok and calls==before+1);before=calls
allowed=false;id='test';m.play();assert(calls==before)
print('PASS row play HTTP: default/selected IDs, rejected invalid IDs, CSRF gate, mocked sound only')

local h=package.loaded['luci.http']
local validator,headers,status,sent,available=nil,{},200,0,true
h.getenv=function(k)return k=='REQUEST_METHOD' and 'GET' or k=='HTTP_IF_NONE_MATCH' and validator end
h.header=function(k,v)headers[k]=v end;h.status=function(v)status=v end;h.write=function(s)sent=sent+#s end
package.loaded['schoolbell.media_web']={sample=function(_,write,ready)
 if not available then return {ok=false}end
 if ready() then write('mp3') end
 return {ok=true}
end}
id='test';m.sample();assert(sent==3 and headers.ETag)
validator=headers.ETag;sent=0;m.sample();assert(status==304 and sent==0)
status=200;validator='"older"';m.sample();assert(status==200 and sent==3)
available=false;validator=headers.ETag;m.sample();assert(status==503)
print('PASS bundled sample: conditional GET checks availability and preserves errors')
