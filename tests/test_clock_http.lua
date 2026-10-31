local C=require('schoolbell.media_codec');local method,size,content,security,code='POST','100','application/x-www-form-urlencoded',true,nil
local form={operation=string.rep('a',32),action='prepare'};local calls,reply=0,nil
local mailbox={submit=function(q)calls=calls+1;assert(q.owner==C.sha('private-session'));return {ok=true,pending=true}end,poll=function(id,owner)assert(id==form.operation and owner==C.sha('private-session'));calls=calls+1;return {ok=true,pending=true}end}
package.loaded['schoolbell.clock_mailbox']={system=function()return mailbox end}
package.loaded['luci.http']={getenv=function(k)return ({REQUEST_METHOD=method,CONTENT_LENGTH=size,CONTENT_TYPE=content})[k]end,status=function(s)code=s end,header=function()end,prepare_content=function()end,write=function(s)reply=C.decode(s)end,formvalue=function(k)return form[k]end}
local dispatcher={context={authsession='private-session'},test_post_security=function()return security end};package.loaded['luci.dispatcher']=dispatcher
-- Existing codec/store modules are used, but no filesystem route is entered.
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
local api=luci.controller.schoolbell_test.clock_trust
api();assert(reply.pending and calls==1)
security=false;api();assert(calls==1)
security=true;size='1025';api();assert(code==413 and calls==1)
size='100';content='application/octet-stream';api();assert(code==413 and calls==1)
content='application/x-www-form-urlencoded';dispatcher.context.authsession=nil;api();assert(code==403 and calls==1)
dispatcher.context.authsession='private-session';method='GET';api();assert(calls==2)
method='POST';form.action='set_time';form.epoch='1790000000';form.ack='true';form.challenge=string.rep('b',32);mailbox.submit=function(q)assert(q.epoch==form.epoch and q.ack=='true' and q.challenge==form.challenge);calls=calls+1;return {ok=true}end;api();assert(calls==3);
method='DELETE';api();assert(code==405 and calls==3)
print('PASS clock HTTP: session ownership, form CSRF, size/type bounds, read-only GET')
