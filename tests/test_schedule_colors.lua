local S=require('schoolbell.schedule_store')
local C=require('schoolbell.media_codec')
local J=require('modbus.json_strict')
local raw='{"pre_minutes":2,"pre_media":"test","schedules":[{"id":"day","name":"Day","rows":[]}]}'
local old,canonical=S.validate(raw);assert(old and old.schedules[1].color==nil and canonical==C.encode(J.decode(raw)))
for n=1,16 do local d=J.decode(raw);d.schedules[1].color=n;local decoded,body=S.validate(C.encode(d));assert(decoded and decoded.schedules[1].color==n);assert(S.validate(body))end
for _,value in ipairs({'0','17','1.5','"1"','true','null','{}'})do local bad=raw:gsub('"name":"Day"','"name":"Day","color":'..value);assert(not S.validate(bad),value)end
local d=J.decode(raw);d.schedules[1].color=16;d.schedules[2]={id='other',name='Other',rows=J.decode('[]'),color=3}
d.schedules[1]=d.schedules[2];d.schedules[2]=nil;local result=S.validate(C.encode(d));assert(result and result.schedules[1].color==3)
assert(S.preview(C.encode(d),'2026-10-25').ok)
print('PASS schedule colors: legacy canonical bytes, 16 IDs, rejected invalid values, delete stability, calendar isolation')
