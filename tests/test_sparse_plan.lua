package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local S=require('schoolbell.schedule_store');local C=require('schoolbell.media_codec');local Cal=require('schoolbell.calendar')
local calls=0;local add=Cal.add_days;Cal.add_days=function(...)calls=calls+1;return add(...)end
local d=C.decode('{"mode":"annual","pre_minutes":2,"pre_media":"test","schedules":[{"id":"s","name":"School","rows":[{"id":"r","time":"08:00","media":"test","enabled":true,"pre":false}]}],"plans":[]}')
d.plans[1]={id='p',name='Leap',start='2024-02-28',['end']='2024-03-01',schedule_ids={'s'},days='.AA'}
local function events(date)local v=S.preview(C.encode(d),date);assert(v.ok);return #v.events end
assert(events('2024-02-28')==0);assert(events('2024-02-29')==1);assert(events('2024-03-01')==1)
d.plans[1]={year=2024,schedule_ids={'s'},days=string.rep('.',365)..'A'}
calls=0;assert(S.validate(C.encode(d)));assert(calls==1,'expand only assigned dates')
assert(events('2024-12-31')==1);assert(events('2024-12-30')==0)
d.plans[1].days=string.rep('.',365)..'B';assert(not S.validate(C.encode(d)))
d.plans[1].days=string.rep('.',365);assert(not S.validate(C.encode(d)))
print('PASS sparse plan: leap/year boundaries, quiet dates, validation and one conversion per assigned date')
