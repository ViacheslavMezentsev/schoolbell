local action=nil;local removed=0
local called,reads=0,0;local env={REQUEST_METHOD='POST',CONTENT_LENGTH='10',CONTENT_TYPE='application/octet-stream',HTTP_AUTHORIZATION='Bearer wrong'};local status;local output
package.loaded['luci.http']={getenv=function(k)return env[k]end,status=function(n)status=n end,
 header=function()end,prepare_content=function()end,write=function(s)output=s end,
 formvalue=function(k,noparse)assert(noparse);return ({action=action,id='user1',name='new.mp3',generation='0',operation=string.rep('a',32)})[k]end,
 source=function()reads=reads+1;return function()end end}
package.loaded['luci.dispatcher']={context={authtoken='secret'}}
package.loaded['schoolbell.media_web']={remove=function(a)removed=removed+1;assert(a.id=='user1');return {ok=true}end,upload=function(a,source)called=called+1;assert((a.size==10 or a.size==65536) and a.id=='user1');return {ok=true}end,list=function()return {ok=true}end,lookup=function()return {ok=true,state='unknown'}end}
package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
local m=luci.controller.schoolbell_test
for _,header in ipairs({'', 'secret', 'Basic secret', 'Bearer secret extra'})do env.HTTP_AUTHORIZATION=header;m.media();assert(status==403 and reads==0)end
env.HTTP_AUTHORIZATION='Bearer wrong'
m.media();assert(status==403 and called==0 and reads==0)
env.HTTP_AUTHORIZATION='Bearer secret';env.CONTENT_LENGTH='65537';m.media();assert(status==413 and called==0 and reads==0)
env.CONTENT_LENGTH='10';env.CONTENT_TYPE='multipart/form-data';m.media();assert(called==0)
env.CONTENT_TYPE='application/octet-stream';m.media();assert(called==1 and reads==1)
env.REQUEST_METHOD='PUT';m.media();assert(status==405 and called==1)
print('PASS media HTTP: token/header, method, body bound, raw source, no body parsing')

env.REQUEST_METHOD='POST';action='delete';env.CONTENT_LENGTH='0';env.HTTP_AUTHORIZATION='Bearer wrong';m.media();assert(removed==0)
env.HTTP_AUTHORIZATION='Bearer secret';m.media();assert(removed==1 and reads==1)
env.CONTENT_LENGTH='1';m.media();assert(status==413 and removed==1)
env.REQUEST_METHOD='GET';m.media();assert(removed==1)
print('PASS delete HTTP: authorized empty POST only, no upload body reads')

action=nil;env.REQUEST_METHOD='POST';env.CONTENT_LENGTH='65536';m.media();assert(called==2 and reads==2)
env.CONTENT_LENGTH='65537';m.media();assert(status==413 and called==2 and reads==2)
print('PASS HTTP exact 64 KiB boundary before reading request body')
