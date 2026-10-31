local env={REQUEST_METHOD='GET'};local code,output,headers;local calls=0;local allow=true;local result={};local action='logout';local destroy_error=nil;local lookup_error=4;local remaining=nil;local lookups=0
package.loaded['luci.http']={getenv=function(k)return env[k]end,status=function(v)code=v end,header=function(k,v)headers[k]=v end,prepare_content=function()end,write=function()end,formvalue=function(k)if k=='action'then return action end end}
local ctx={authsession='server-session',authuser='root',authtoken=string.rep('a',32)}
package.loaded['luci.dispatcher']={context=ctx,build_url=function()return '/cgi-bin/luci'end,test_post_security=function()return allow end}
package.loaded['luci.util']={ubus=function(o,m,a)
 assert(o=='session' and a.ubus_rpc_session=='server-session')
 if m=='destroy'then calls=calls+1;return result,destroy_error end
 assert(m=='get');lookups=lookups+1;return remaining,lookup_error
end}
package.loaded['schoolbell.schedule_store']={}
package.loaded['schoolbell.media_codec']={encode=function(v)output=v;return '{}'end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
local m=luci.controller.schoolbell_test
local function invoke(method)env.REQUEST_METHOD=method;code=nil;output=nil;headers={};m.session()end
invoke('GET');assert(output.ok and output.user=='root' and output.token==ctx.authtoken and not output.authsession and calls==0 and headers['Cache-Control']=='no-store')
ctx.authsession=nil;invoke('GET');assert(code==401 and calls==0);ctx.authsession='server-session'
invoke('PUT');assert(code==405 and calls==0)
allow=false;invoke('POST');assert(calls==0);allow=true;action='anything';invoke('POST');assert(code==400 and calls==0)
action='logout';invoke('POST');assert(calls==1 and output.logged_out and headers['Set-Cookie']:match('sysauth=;'))
result=nil;invoke('POST');assert(calls==2 and output.logged_out and lookups==2)
for _,e in ipairs({1,7,10})do destroy_error=e;invoke('POST');assert(code==503 and not output.ok and not headers['Set-Cookie'])end
destroy_error=nil
for _,e in ipairs({0,1,7,10})do lookup_error=e;invoke('POST');assert(code==503 and not output.ok and not headers['Set-Cookie'])end
lookup_error=nil;invoke('POST');assert(code==503)
lookup_error=4;remaining={};invoke('POST');assert(code==503)
remaining=nil;invoke('POST');assert(output.logged_out)

print('PASS session GET/no session/method/CSRF/action; destroy server-owned SID only; failure not success')
