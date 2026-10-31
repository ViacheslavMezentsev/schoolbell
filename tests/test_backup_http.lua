local calls,reads=0,0;local env={REQUEST_METHOD='POST',CONTENT_LENGTH='10',CONTENT_TYPE='application/octet-stream',HTTP_AUTHORIZATION='Bearer wrong'};local status;local action='restore';local operation=string.rep('a',32)
package.loaded['luci.http']={getenv=function(k)return env[k]end,status=function(n)status=n end,header=function()end,prepare_content=function()end,write=function()end,
 formvalue=function(k,noparse)assert(noparse);return ({action=action,operation=operation})[k]end,source=function()reads=reads+1;return function()end end}
package.loaded['luci.dispatcher']={context={authtoken='secret'}}
package.loaded['schoolbell.backup_web']={restore=function(op,src,size)calls=calls+1;assert(size==10);return {ok=true}end,resume=function()calls=calls+1;return {ok=true}end,status=function()calls=calls+1;return {ok=true}end,export=function(write)calls=calls+1;write('SBBACKUP1');return {ok=true}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua');local m=luci.controller.schoolbell_test
for _,header in ipairs({'', 'secret', 'Basic secret', 'Bearer secret extra'})do env.HTTP_AUTHORIZATION=header;m.backup();assert(status==403 and reads==0)end
env.HTTP_AUTHORIZATION='Bearer wrong'
m.backup();assert(status==403 and calls==0 and reads==0)
env.HTTP_AUTHORIZATION='Bearer secret';env.CONTENT_LENGTH='2162817';m.backup();assert(status==413 and calls==0 and reads==0)
env.CONTENT_LENGTH='10';env.CONTENT_TYPE='multipart/form-data';m.backup();assert(calls==0)
env.CONTENT_TYPE='application/octet-stream';operation='../bad';m.backup();assert(status==400 and calls==0 and reads==0)
operation=string.rep('a',32);m.backup();assert(calls==1 and reads==1)
action='resume';m.backup();assert(status==400 and calls==1);env.CONTENT_LENGTH='0';m.backup();assert(calls==2 and reads==1)
env.REQUEST_METHOD='PUT';m.backup();assert(status==405 and calls==2)
env.REQUEST_METHOD='GET';action='restore';m.backup();assert(status==400 and calls==2)
action='status';m.backup();action='download';m.backup();assert(calls==4 and reads==1)
print('PASS backup HTTP: CSRF, bounded raw input, action/operation, no GET mutation, resume without body')
