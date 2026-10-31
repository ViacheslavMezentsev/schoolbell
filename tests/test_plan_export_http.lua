local env={REQUEST_METHOD='POST',HTTP_AUTHORIZATION='Bearer wrong',CONTENT_LENGTH='100',CONTENT_TYPE='application/json'}
local status,reads,calls=0,0,0;local raw='{"selected":["one"],"revision":"'..string.rep('a',64)..'"}'
package.loaded['luci.http']={getenv=function(k)return env[k]end,status=function(n)status=n end,content=function()reads=reads+1;return raw end,header=function()end,prepare_content=function()end,write=function()end}
package.loaded['luci.dispatcher']={context={authtoken='secret'}}
package.loaded['schoolbell.plan_export_web']={download=function(ids,rev,start,emit)calls=calls+1;assert(ids[1]=='one');start({size=100});emit('data');return {ok=true}end}
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua');local api=luci.controller.schoolbell_test
api.plan_export();assert(status==403 and reads==0)
env.HTTP_AUTHORIZATION='Bearer secret';env.CONTENT_LENGTH='4097';api.plan_export();assert(status==413 and reads==0)
env.CONTENT_LENGTH='100';env.REQUEST_METHOD='GET';api.plan_export();assert(status==405 and reads==0)
env.REQUEST_METHOD='POST';raw='{"selected":[],"revision":"'..string.rep('a',64)..'"}';api.plan_export();assert(status==400 and calls==0)
raw='{"selected":["one"],"revision":"'..string.rep('a',64)..'"}';api.plan_export();assert(calls==1)
print('PASS export HTTP: POST/session CSRF before body, length/selection guards, completed file before response')
