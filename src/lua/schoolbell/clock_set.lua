-- Explicit administrator action. Worker-owned, single-use challenge; no NTP/UCI.
local M={min_epoch=1577836800,max_epoch=2145916799,ttl=60,max_queue=5}
function M.epoch(s)
 if type(s)~='string' or not s:match('^[0-9]+$') or #s~=10 then return nil end
 local n=tonumber(s);if n<M.min_epoch or n>M.max_epoch then return nil end;return n
end
function M.new(gate,io)
 local challenge
 local function fail(code)return {ok=false,code=code}end
 return function(q,meta)
  if q.action~='set_prepare' and q.action~='set_time'then return fail('invalid_action')end
  local epoch=M.epoch(q.epoch);if not epoch then return fail('calendar_range')end
  local now=io.monotonic()
  if q.action=='set_prepare'then
   challenge={id=q.id,owner=q.owner,epoch=epoch,at=now,zone=io.zone()}
   return {ok=true,challenge=q.id,utc=io.read(),zone=challenge.zone,ttl=M.ttl}
  end
  local old=challenge
  if not old or q.challenge~=old.id or q.owner~=old.owner then return fail('stale_confirmation')end
  challenge=nil -- consumed even on refusal; never reuse after partial effects
  if q.ack~='true' or now<old.at or now-old.at>=M.ttl or io.zone()~=old.zone then return fail('stale_confirmation')end
  local queued=meta and meta.submitted_at
  if type(queued)~='number' or queued>now or now-queued>M.max_queue then return fail('clock_request_expired')end
  local target=epoch+math.floor(now-queued)
  if target>M.max_epoch or math.abs(target-(old.epoch+now-old.at))>15 then return fail('browser_clock_changed')end
  local release=io.lock()
  if not release then return fail('sound_busy')end
  local attempted=false
  local ok,result=pcall(function()
   gate.invalidate()
   if not io.stop()then return fail('disable_failed')end
   -- Stopping/persistence can take time: include it, but never install a stale value.
   local ready=io.monotonic()
   if ready<now or ready-queued>M.max_queue or ready-old.at>=M.ttl then return fail('clock_request_expired')end
   target=epoch+math.floor(ready-queued)
   if target>M.max_epoch then return fail('calendar_range')end
   attempted=true
   if io.set(target)~=true then return fail('clock_set_failed')end
   local after,ended=io.read(),io.monotonic()
   if ended<ready or ended-ready>2 or type(after)~='number' or math.abs(after-(target+ended-ready))>2 then return fail('clock_verify_failed')end
   return {ok=true,utc=after,automatic_enabled=false,confirmation_required=true}
  end)
  -- Read trust anew after a step; never retain a pre-step confirmation, even on error.
  local invalidated=pcall(gate.invalidate)
  local closed,done=pcall(release)
  if not invalidated or not closed or done~=true then return fail('clock_cleanup_failed')end
  if not ok then return fail(attempted and 'outcome_unknown' or 'operation_failed')end
  return result
 end
end
-- Only a fixed command made from validated UTC numeric components can reach a shell.
-- Same date parser as OpenWrt 19.07 LuCI, with -u to avoid DST/local-zone ambiguity.
function M.system_set(epoch,execute)
 if type(epoch)~='number' or epoch~=math.floor(epoch) or not M.epoch(tostring(epoch))then return false end
 local t=os.date('!*t',epoch)
 local command=string.format("/bin/date -u -s '%04d-%02d-%02d %02d:%02d:%02d' >/dev/null 2>&1",t.year,t.month,t.day,t.hour,t.min,t.sec)
 return (execute or os.execute)(command)==0
end
function M.system(gate,stop,zone,monotonic)
 local fs=require('nixio.fs');local sound=require('schoolbell.sound_test').lock
 return M.new(gate,{monotonic=monotonic,read=os.time,zone=zone,stop=stop,set=M.system_set,
  lock=function()
   if not fs.mkdir(sound,700)then return nil end
   return function()return fs.rmdir(sound)end
  end})
end
return M
