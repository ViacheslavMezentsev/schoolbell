local calls,body=0,0
local env={REQUEST_METHOD='POST',HTTP_AUTHORIZATION='Bearer wrong',CONTENT_LENGTH='100',CONTENT_TYPE='multipart/form-data; boundary=x'}
local action='upload';local id=string.rep('a',32);local status,handler
package.loaded['luci.http']={getenv=function(k)return env[k]end,status=function(n)status=n end,header=function()end,prepare_content=function()end,write=function()end,
 setfilehandler=function(fn)handler=fn end,content=function()body=body+1;return '{"operation_id":"'..id..'","names":{"plans":{},"schedules":{}}}'end,
 formvalue=function(k,query)if query then return ({action=action,operation_id=id})[k]end;body=body+1;handler({name='file'},'SBPLAN1',true)end}
package.loaded['luci.dispatcher']={context={authtoken='secret'}}
package.loaded['schoolbell.plan_import_web']={request=function(a,op,args,pump,size)calls=calls+1;assert(op==id);if pump then pump(function(chunk)assert(chunk=='SBPLAN1')end)end;return {ok=true,state='validated',operation_id=op,code='ok'}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua');local m=luci.controller.schoolbell_test
m.plan_import();assert(status==403 and body==0 and calls==0)
env.HTTP_AUTHORIZATION='Bearer secret';env.CONTENT_LENGTH='2134099';m.plan_import();assert(status==413 and body==0)
env.CONTENT_LENGTH='100';env.CONTENT_TYPE='application/octet-stream';m.plan_import();assert(status==400 and body==0)
env.CONTENT_TYPE='multipart/form-data; boundary=x';m.plan_import();assert(calls==1 and body==1)
action='preview';env.CONTENT_TYPE='application/json';m.plan_import();assert(calls==2 and body==2)
env.REQUEST_METHOD='GET';m.plan_import();assert(status==405 and calls==2);action='status';m.plan_import();assert(calls==3 and body==2)
env.REQUEST_METHOD='PUT';m.plan_import();assert(status==405 and calls==3)
print('PASS plan import HTTP: early CSRF/size/type checks, multipart, bounded JSON, GET only status')
