-- AC-03 / TC-31: literal expected moments, independent of schedule preview.
local A=require('schoolbell.automatic');local S=require('schoolbell.schedule_store')
local d=S.empty();d.fixed_schedule='school';d.pre_minutes=2;d.pre_media='test'
local times={'07:55','08:00','08:45','08:55','09:40','10:00','10:45','11:05','11:50','12:10','12:55','13:05','13:50','14:00','14:45'}
local pre={[4]=true,[6]=true,[8]=true,[10]=true,[12]=true,[14]=true}
local rows={};for i,time in ipairs(times)do rows[i]={id='r'..i,time=time,media='1',enabled=true,pre=pre[i] or false}end
-- A disabled row must not add either its main or preliminary event.
rows[#rows+1]={id='disabled',time='15:00',media='1',enabled=false,pre=true}
d.schedules={{id='school',name='School',rows=rows}}
local expected={'07:55','08:00','08:45','08:53','08:55','09:40','09:58','10:00','10:45','11:03','11:05','11:50','12:08','12:10','12:55','13:03','13:05','13:50','13:58','14:00','14:45'}
local preliminary={['08:53']=true,['09:58']=true,['11:03']=true,['12:08']=true,['13:03']=true,['13:58']=true}
local function check(date)
 local events=assert(A.events(d,date));assert(#events==21)
 for i,time in ipairs(expected)do
  assert(events[i].time==time,'oracle moment '..i)
  assert(events[i].media==(preliminary[time] and 'test' or '1'),'oracle media '..i)
  assert(os.date('%Y-%m-%d %H:%M:%S',events[i].utc)==date..' '..time..':00','libc moment '..i)
 end
 -- Real engineering engine driven once per second, no browser or process.
 local engine=A.new(events[1].utc-1,0,0);local played={}
 for utc=events[1].utc,events[#events].utc+1 do
  local event,skip=engine.step(utc,utc-events[1].utc+1,events,false)
  if event then assert(not skip);played[#played+1]=event.time end
 end
 assert(#played==#expected);for i,time in ipairs(expected)do assert(played[i]==time)end
 print('PASS independent 15+6 worker-calendar oracle '..date..' '..d.mode)
end
check('2026-10-25');check('2026-10-26')
d.mode='annual';d.plans={{year=2026,schedule_ids={'school'},days=string.rep('.',297)..'A'..string.rep('.',67)}}
check('2026-10-25')
assert(#assert(A.events(d,'2026-10-24'))==0)
assert(#assert(A.events(d,'2026-10-26'))==0)
assert(#assert(A.events(d,'2027-10-25'))==0)
print('PASS annual quiet/unassigned dates and no automatic yearly repeat')
