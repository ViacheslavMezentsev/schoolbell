-- Engineering scheduler policy: no backlog, one admission per instant.
local M={grace=2,max_gap=3}
function M.new(now,mono,watermark)
 local high=math.max(now,watermark or 0);local last,previous=mono,now
 return {watermark=function()return high end,step=function(now,mono,events,muted)
  local floor=high;high=math.max(high,now)
  local gap=mono-last;local jump=math.abs((now-previous)-gap)>2
  local forward_jump=jump and now>previous
  last,previous=mono,now
  local reason=(gap<0 or gap>M.max_gap or jump) and 'clock_gap' or nil
  local due
  for _,event in ipairs(events)do if event.utc>floor and event.utc<=now then due=event end end
  if due then
   return due,reason or (now-due.utc>M.grace and 'expired') or (muted and 'muted') or nil
  end
  return nil,reason,forward_jump
 end}
end
-- libc local time is accepted only after a roundtrip. Probe both DST branches.
function M.resolve(date,time,clock)
 clock=clock or os;local y,m,d=date:match('^(%d+)%-(%d+)%-(%d+)$')
 local h,mi=time:match('^(%d+):(%d+)$');local out,seen={},{}
 for _,dst in ipairs({false,true})do
  local n=clock.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(h),min=tonumber(mi),sec=0,isdst=dst})
  if n and clock.date('%Y-%m-%d %H:%M:%S',n)==date..' '..time..':00' and not seen[n]then out[#out+1]=n;seen[n]=true end
 end
 table.sort(out);return out
end
function M.events(data,date,resolver)
 local S=require('schoolbell.schedule_store');local C=require('schoolbell.media_codec')
 local out=S.preview(C.encode(data),date)
 if not out.ok then return nil,'calendar_invalid' end
 local seen={}
 for _,e in ipairs(out.events)do
  local candidates=(resolver or M.resolve)(e.date,e.time)
  if #candidates~=1 then return nil,#candidates==0 and 'nonexistent_time' or 'ambiguous_time' end
  e.utc=candidates[1]
  if seen[e.utc]then return nil,'simultaneous_events' end;seen[e.utc]=true
 end
 table.sort(out.events,function(a,b)return a.utc<b.utc end)
 return out.events
end
return M
