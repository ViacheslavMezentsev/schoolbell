-- Durable aggregation of the package journal. No player or scheduler commands.
local C=require('schoolbell.media_codec')
local J=require('modbus.json_strict')
local M={max_days=400,max_bytes=16384}
local name='bell-metrics.json'
local function day(v)
 if type(v)~='string'then return false end
 local y,m,d=v:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$');y,m,d=tonumber(y),tonumber(m),tonumber(d)
 if not y or y<1 or m<1 or m>12 then return false end
 local lengths={31,(y%4==0 and (y%100~=0 or y%400==0))and 29 or 28,31,30,31,30,31,31,30,31,30,31}
 return d>=1 and d<=lengths[m]
end
function M.load(fs)
 local raw=fs.read(name,M.max_bytes)
 if not raw then return {version=1,cursor=0,days=assert(J.decode('[]'))}end
 local v=assert(J.decode(raw),'metrics JSON');C.fields(v,{'version','cursor','days'})
 assert(v.version==1 and C.integer(v.cursor,0,2147483647) and J.kind(v.days)=='array' and #v.days<=M.max_days,'metrics schema')
 local seen={}
 for _,r in ipairs(v.days)do C.fields(r,{'date','count'});assert(day(r.date) and not seen[r.date] and C.integer(r.count,0,999999999),'metrics day');seen[r.date]=true end
 return v
end
function M.project(v,rows,date,last)
 date=date or function(t)return os.date('%Y-%m-%d',t)end
 assert(v.cursor==0 or (last or (#rows>0 and rows[#rows].seq) or 0)>=v.cursor,'journal sequence regressed')
 local changed=false
 for _,r in ipairs(rows)do
  if r.seq>v.cursor and (r.action=='auto_ok' or r.action=='auto_enabled')then
   local d=date(r.time);assert(day(d),'date');local target
   for _,old in ipairs(v.days)do if old.date==d then target=old;break end end
   if not target then
    if #v.days==M.max_days then table.remove(v.days,1)end
    target={date=d,count=0};v.days[#v.days+1]=target
   end
   if r.action=='auto_ok'then assert(target.count<999999999,'counter exhausted');target.count=target.count+1 end
   v.cursor=r.seq;changed=true
  end
 end
 return v,changed
end
function M.sync(fs,rows,date,last)
 local v,changed=M.project(M.load(fs),rows,date,last)
 if not changed then return v end
 local raw=C.encode(v);assert(#raw<=M.max_bytes,'metrics size')
 assert(fs.space()>=65536+M.max_bytes,'metrics reserve')
 if fs.stat('bell-metrics.next')then fs.unlink('bell-metrics.next')end
 fs.write('bell-metrics.next',raw);fs.sync('bell-metrics.next')
 fs.rename('bell-metrics.next',name);fs.sync('')
 return v
end
function M.reconcile(root)
 local fs
 local ok=pcall(function()
  fs=require('schoolbell.media_fs').new(root)
  local rows,last=require('schoolbell.journal').read(fs)
  M.sync(fs,rows,nil,last)
 end)
 if fs then local closed=pcall(fs.close);ok=ok and closed end
 return ok
end
function M.request(root,reader)
 local fs
 local ok,result=pcall(function()
  fs=reader or require('schoolbell.media_fs').readonly(root)
  local v=M.load(fs);local pending=false;local newest=0
  -- Read only the checkpoint and scan bounded journal bytes for a newer relevant seq.
  -- Atomic published snapshots need no shared editor lock on a UI poll.
  local names,segment=require('schoolbell.journal').layout(fs)
  for _,name in ipairs(names)do
   local raw=fs.read(name,segment) or ''
   if raw~='' and raw:sub(-1)~='\n' then pending=true end
   for line in raw:gmatch('([^\n]+)\n')do
    newest=math.max(newest,tonumber(line:match('"seq":(%d+)')) or 0)
    if line:find('"action":"auto_ok"',1,true) or line:find('"action":"auto_enabled"',1,true)then
     local seq=tonumber(line:match('"seq":(%d+)'))
     if not seq or seq>v.cursor then pending=true end
    end
   end
  end
  if newest<v.cursor then pending=true end
  return {ok=true,today=os.date('%Y-%m-%d'),days=v.days,persistence_pending=pending,max_days=M.max_days}
 end)
 if fs then local closed=pcall(fs.close);ok=ok and closed end
 if not ok then return {ok=false,code='metrics_unavailable'}end
 return result
end
return M
