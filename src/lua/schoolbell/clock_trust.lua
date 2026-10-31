-- Isolated clock trust model, milliseconds throughout. Caller drives observation.
-- clock() -> {before_ms,utc_ms,after_ms,context}; context identifies boot/observer/TZ epoch.
-- valid_utc(ms) is mandatory: the system adapter owns its supported calendar range.
-- No player actions, event replay, NTP, network, filesystem or clock writes here.
local C=require('schoolbell.clock_reference')
local M={period_ms=1000,max_gap_ms=3000,pair_max_ms=100,checkpoint_ms=3600000,confirm_ttl_ms=15000}
function M.new(io,options)
 assert(type(io)=='table' and type(io.clock)=='function' and type(io.valid_utc)=='function' and type(io.store)=='table','ports')
 options=options or {}
 local function threshold(v)assert(type(v)=='number' and v==math.floor(v) and v>=1 and v<=60,'threshold');return v*1000 end
 local rollback=threshold(options.rollback_seconds==nil and 5 or options.rollback_seconds);local step=threshold(options.step_seconds==nil and 5 or options.step_seconds)
 local state,reason='unconfirmed','startup';local enabled=false;local last,reference,revision,saved_at,token
 local storage_fault=false;local events={};local dropped=0
 local function revoke()enabled=false;token=nil end
 local function transition(s,r)
  if state~=s or reason~=r then
   if #events==16 then table.remove(events,1);dropped=dropped+1 end
   events[#events+1]={state=s,reason=r}
  end
  if s~='confirmed'then revoke()end;state,reason=s,r
 end
 local loaded_ok,loaded=pcall(io.store.load)
 if not loaded_ok or type(loaded)~='table' or not loaded.ok then storage_fault=true;reason='reference_unavailable'
 else
  local good,value=pcall(function()
   if loaded.data==nil then assert(loaded.revision=='empty');return nil end
   local raw,hash=C.encode(loaded.data);assert(hash==loaded.revision);return C.decode(raw)
  end)
  if not good then storage_fault=true;reason='reference_unavailable'
  else reference=value;revision=loaded.revision end
 end
 local function snapshot()
  return {state=state,reason=reason,enabled=enabled,source=reference and reference.source or nil,
   confirmed_utc_ms=reference and reference.confirmed_utc_ms or nil,checkpoint_utc_ms=reference and reference.checkpoint_utc_ms or nil,
   rollback_seconds=rollback/1000,step_seconds=step/1000,accuracy_known=false}
 end
 local function sample()
  local ok,p=pcall(io.clock)
  if not ok or type(p)~='table' or not C.integer(p.before_ms) or not C.integer(p.after_ms) or not C.integer(p.utc_ms)
   or type(p.context)~='string' or #p.context==0 or #p.context>256 then return nil,'clock_read' end
  local valid,accept=pcall(io.valid_utc,p.utc_ms)
  if not valid or accept~=true then return nil,'calendar_range' end
  if p.after_ms<p.before_ms or p.after_ms-p.before_ms>M.pair_max_ms then return nil,'clock_pair' end
  -- Copy ports' mutable results; no borrowed references in the model.
  return {before_ms=p.before_ms,after_ms=p.after_ms,utc_ms=p.utc_ms,context=p.context}
 end
 local function save(p,confirmed)
  local data={format='schoolbell-clock/1',source='manual',confirmed_utc_ms=confirmed and p.utc_ms or reference.confirmed_utc_ms,
   checkpoint_utc_ms=confirmed and p.utc_ms or math.max(reference.checkpoint_utc_ms,p.utc_ms)}
  local _,expected=C.encode(data)
  local ok,result=pcall(io.store.save,data,revision)
  if not ok or type(result)~='table' or not result.ok or result.revision~=expected then
   storage_fault=true;transition('review_required','reference_write');return false
  end
  reference=data;revision=result.revision;saved_at=p.after_ms;return true
 end
 local function observe(checkpoint)
  local p,err=sample()
  if not p then last=nil;transition('review_required',err);return nil end
  local previous=last;last=p
  if previous then
   if previous.context~=p.context then saved_at=nil;transition('unconfirmed','context_changed');previous=nil
   elseif p.before_ms<previous.before_ms or p.after_ms<previous.after_ms then transition('review_required','monotonic_reversed')
   elseif p.after_ms-previous.before_ms>M.max_gap_ms then transition('review_required','observation_gap')
   else
    local delta=p.utc_ms-previous.utc_ms
    -- UTC samples happened somewhere inside their MONO brackets. Evaluate the
    -- entire possible jump interval, never assume symmetric sampling latency.
    local low=delta-(p.after_ms-previous.before_ms)
    local high=delta-(p.before_ms-previous.after_ms)
    if low < -step or high > step then
     transition('review_required',(low>step or high < -step) and 'clock_step' or 'clock_step_uncertain')
    end
   end
  end
  if storage_fault then transition('review_required','reference_unavailable')
  elseif state=='unconfirmed' and reference and reference.checkpoint_utc_ms-p.utc_ms>rollback then transition('rollback_detected','before_reference')end
  if checkpoint and state=='confirmed' and saved_at and p.after_ms-saved_at>=M.checkpoint_ms then
   if save(p,false)then
    -- A slow persistence operation must not leave a stale permit valid.
    local fresh=observe(false)
    if fresh and state=='confirmed'then saved_at=fresh.after_ms end
    return fresh
   end
  end
  return p
 end
 -- Lua local-function recursion is used above: all observations pass through the same guard.
 local api={}
 function api.observe(checkpoint)observe(checkpoint~=false);return snapshot()end
 function api.status()return snapshot()end -- cached diagnostic snapshot, never an admission permit
 function api.drain_events()local out=events;events={};local lost=dropped;dropped=0;return out,lost end
 function api.request_confirmation()
  local p=observe(true);if not p or storage_fault then return nil,'unavailable' end
  token=nil;local id={} -- instance-local opaque capability, not a wire/auth token
  token={id=id,issued=p.before_ms,context=p.context,utc=p.utc_ms,revision=revision}
  return {token=id,utc_ms=p.utc_ms,context=p.context,requires_rollback_ack=reference~=nil and p.utc_ms<reference.checkpoint_utc_ms}
 end
 function api.confirm(id,acknowledge_rollback)
  local t=token;local p=observe(false)
  if not t or not p or token~=t or t.id~=id or t.context~=p.context or t.revision~=revision or p.after_ms-t.issued>=M.confirm_ttl_ms then
   token=nil;return {ok=false,code='stale_confirmation'}
  end
  token=nil;enabled=false
  if storage_fault then return {ok=false,code='reference_unavailable'}end
  if reference and p.utc_ms<reference.checkpoint_utc_ms and acknowledge_rollback~=true then return {ok=false,code='rollback_ack_required'}end
  if not save(p,true)then return {ok=false,code='reference_write'}end
  transition('confirmed','manual_confirmation')
  observe(false) -- reject a clock step/context loss or long pause during commit
  if state~='confirmed'then return {ok=false,code='observation_lost'}end
  saved_at=last.after_ms -- period starts after completed persistence, not before it
  return {ok=true}
 end
 function api.enable()
  observe(true);if state~='confirmed'then return {ok=false,code='clock_untrusted'}end
  enabled=true;return {ok=true}
 end
 function api.disable()enabled=false end
 function api.admit()observe(true);return state=='confirmed' and enabled end
 function api.configure(settings)
  local ok,a,b=pcall(function()assert(type(settings)=='table');return threshold(settings.rollback_seconds),threshold(settings.step_seconds)end)
  if not ok then return {ok=false,code='invalid_threshold'}end
  rollback,step=a,b;revoke();return {ok=true}
 end
 return api
end
return M
