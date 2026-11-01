package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local calls,allowed=0,true;local result,status
local env={REQUEST_METHOD='POST',CONTENT_LENGTH='100',CONTENT_TYPE='application/x-www-form-urlencoded'}
local values={operation=string.rep('a',32),action='system_prepare',target='reboot'}
package.loaded['luci.http']={getenv=function(k)return env[k]end,formvalue=function(k)return values[k]end,status=function(v)status=v end,header=function()end,prepare_content=function()end,write=function()end}
package.loaded['luci.dispatcher']={context={authsession='session'},test_post_security=function()return allowed end}
package.loaded['schoolbell.clock_mailbox']={system=function()return {submit=function(q)calls=calls+1;result=q;return {ok=true}end,poll=function()return {ok=true,pending=true}end}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua');local api=luci.controller.schoolbell_test
allowed=false;api.system_action();assert(calls==0);allowed=true
api.system_action();assert(calls==1 and result.owner and result.target=='reboot')
values.action='enable';api.system_action();assert(status==400 and calls==1)
env.REQUEST_METHOD='GET';api.system_action();assert(calls==1)
env.REQUEST_METHOD='POST';env.CONTENT_LENGTH='1025';api.system_action();assert(status==413 and calls==1)
env.CONTENT_LENGTH='100';package.loaded['luci.dispatcher'].context.authsession=nil;api.system_action();assert(status==403)
print('PASS system HTTP: authenticated session, CSRF, bounded POST, action whitelist, read-only GET')
