-- Diagnostic telemetry only. Writers already hold the mailbox lock; readers do not.
local C=require('schoolbell.media_codec');local M={}
local function fresh(now,epoch)return {version=1,epoch=epoch,at=math.floor(now),depth=0,running=0,bins={}}end
local function bin(s,now)
 local key=math.floor(now/5);local keep={};local current
 for _,b in ipairs(s.bins)do if b.key>key-12 and b.key<=key then keep[#keep+1]=b;if b.key==key then current=b end end end
 s.bins=keep
 if not current then current={key=key,depth=s.depth,running=s.running,processed=0,failed=0,expired=0,wait_count=0,wait_sum=0,wait_max=0};keep[#keep+1]=current end
 return current
end
function M.valid(s)
 if type(s)~='table' or s.version~=1 or type(s.epoch)~='string' or #s.epoch>64 or type(s.bins)~='table' or #s.bins>12 then return false end
 local function number(v,max)return type(v)=='number' and v>=0 and v<=max and v==math.floor(v)end
 if not number(s.at,2147483647) or not number(s.depth,1) or not number(s.running,1)then return false end
 local previous=-1
 for _,b in ipairs(s.bins)do
  if type(b)~='table' or not number(b.key,429496729) or b.key<=previous then return false end;previous=b.key
  for _,k in ipairs({'depth','running'})do if not number(b[k],1)then return false end end
  for _,k in ipairs({'processed','failed','expired','wait_count','wait_sum','wait_max'})do if not number(b[k],2147483647)then return false end end
 end
 return true
end
function M.apply(s,event,now,value,epoch)
 if not M.valid(s) or now<s.at or event=='reset' then s=fresh(now,epoch or 'pending-worker')end
 for key=math.max(math.floor(s.at/5),math.floor(now/5)-11),math.floor(now/5)do bin(s,key*5)end
 local b=bin(s,now)
 if event=='queued'then s.depth=1;b.depth=1
 elseif event=='start'then
  s.depth=0;s.running=1;b.running=1
  if value and value>=0 then local ms=math.min(2147483647,math.floor(value*1000+0.5));b.wait_count=b.wait_count+1;b.wait_sum=math.min(2147483647,b.wait_sum+ms);b.wait_max=math.max(b.wait_max,ms)end
 elseif event=='finish'then s.depth=0;s.running=0;b.processed=b.processed+1;if value==false then b.failed=b.failed+1 end
 elseif event=='expired'then s.depth=0;s.running=0;b.expired=b.expired+1
 end
 s.at=math.floor(now);return s
end
function M.observer(now,worker,epoch)
 local initialized=false
 return function(fs,event,value)
  local raw=fs.read('metrics.json',4096);local s=raw and C.decode(raw)
  local reset=worker and not initialized
  if reset then s=M.apply(s,'reset',now(),nil,epoch);s.depth=fs.stat('request.json') and 1 or 0;s.bins[1].depth=s.depth;initialized=true end
  if not reset and event=='tick' and M.valid(s) and math.floor(now()/5)==math.floor(s.at/5)then return end
  s=M.apply(s,event,now(),value,epoch)
  local encoded=C.encode(s);assert(#encoded<=4096)
  if fs.stat('metrics.next')then fs.unlink('metrics.next')end
  fs.write('metrics.next',encoded);fs.rename('metrics.next','metrics.json')
 end
end
function M.read()
 local ok,result=pcall(function()
  local f=io.open('/tmp/schoolbell-clock-control/metrics.json','rb');if not f then return {available=false}end
  local raw=f:read(4097);f:close();assert(raw and #raw<=4096)
  local s=C.decode(raw);assert(M.valid(s))
  local f=assert(io.open('/proc/uptime','r'));local now=tonumber(f:read(64):match('^[%d.]+'));f:close()
  assert(now>=s.at and now-s.at<=15)
  -- Explicit public fields, never request IDs, owners, challenges or payloads.
  local public={};for _,b in ipairs(s.bins)do local v={};for _,key in ipairs({'key','depth','running','processed','failed','expired','wait_count','wait_sum','wait_max'})do v[key]=b[key]end;public[#public+1]=v end
  return {available=true,epoch=s.epoch,at=s.at,now=math.floor(now),depth=s.depth,running=s.running,bins=public}
 end)
 return ok and result or {available=false}
end
return M
