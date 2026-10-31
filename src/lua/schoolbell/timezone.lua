-- Settings are applied only by explicit authenticated POST; no epoch adjustment.
local C=require('schoolbell.media_codec')
local J=require('modbus.json_strict')
local M={}
function M.request(backend,zone,revision)
 local ok,result=pcall(function()
  local state=backend.read();local zones=backend.zones()
  if zone==nil then
   local list=assert(J.decode('[]'));for name in pairs(zones)do list[#list+1]=name end;table.sort(list)
   return {ok=true,zone=state.zone,revision=state.revision,zones=list,pending=state.pending,runtime_ok=backend.matches(zones[state.zone])}
  end
  if type(zone)~='string' or not zones[zone] then return {ok=false,code='invalid_zone'}end
  if type(revision)~='string' or revision~=state.revision then return {ok=false,code='conflict'}end
  if state.pending then return {ok=false,code='pending_changes'}end
  if zone==state.zone and backend.matches(zones[zone])then return {ok=true,zone=zone,unchanged=true}end
  if zone~=state.zone or state.posix~=zones[zone] then
   if not backend.commit(zone,zones[zone],state.revision)then return {ok=false,code='save_uncertain'}end
  end
  if not backend.apply() or not backend.matches(zones[zone])then return {ok=false,code='apply_failed',saved=true}end
  return {ok=true,zone=zone}
 end)
 return ok and result or {ok=false,code='unavailable'}
end
function M.system(options)
 local opts=options or {};local config=opts.config_dir or "/etc/config";local runtime=opts.runtime_file or "/tmp/TZ"
 local fs=require('nixio.fs');local n=require('nixio')
 local path='/tmp/schoolbell-timezone-'..n.getpid();assert(not fs.lstat(path),'staging exists');assert(fs.mkdir(path,700))
 local function quote(s)return "'"..s:gsub("'", "'\\''").."'" end
 -- -P disables commit on target UCI; use -p only for the commit invocation.
 local base='/sbin/uci -q -c '..quote(config)..' -P '..quote(path)..' '
 local function readuci(command)
  local f=assert(io.popen(base..command..' 2>/dev/null','r'));local text=f:read(32769) or '';f:close()
  assert(text and #text<=32768,'uci size');return text:gsub('[\r\n]+$','')
 end
 local function writeuci(command)return os.execute(base..command..' >/dev/null 2>&1')==0 end
 local function raw(file)
  local f=assert(io.open(file,'rb'));local data=f:read(32769);f:close();assert(data and #data<=32768,'size');return data
 end
 local backend={}
 function backend.zones()
  local out={UTC='UTC'}
  for _,item in ipairs(require('luci.sys.zoneinfo.tzdata').TZ)do out[item[1]]=item[2]end
  return out
 end
 function backend.read()
  local section,count=nil,0
  for line in (readuci('show system')..'\n'):gmatch('(.-)\n')do
   local name=line:match('^system%.([%w_@%[%]%-]+)=system$')
   if name then section=name;count=count+1 end
  end
  assert(count==1,'system section count')
  local zone=readuci('get '..quote('system.'..section..'.zonename'))
  local posix=readuci('get '..quote('system.'..section..'.timezone'))
  local pending=fs.stat(opts.pending_file or '/tmp/.uci/system')
  return {zone=zone~='' and zone or 'UTC',posix=posix~='' and posix or 'UTC',section=section,
   revision=C.sha(raw(config..'/system')),pending=pending and pending.size>0 or false}
 end
 function backend.commit(zone,posix,revision)
  local state=backend.read();if state.revision~=revision or state.pending then return false end
  assert(writeuci('set '..quote('system.'..state.section..'.zonename='..zone)))
  assert(writeuci('set '..quote('system.'..state.section..'.timezone='..posix)))
  assert(os.execute('/sbin/uci -q -c '..quote(config)..' -p '..quote(path)..' commit system >/dev/null 2>&1')==0)
  local after=backend.read()
  return after.revision~=revision and after.zone==zone and after.posix==posix
 end
 function backend.apply()if opts.apply then return opts.apply()end;return os.execute('/etc/init.d/system reload >/dev/null 2>&1')==0 end
 function backend.matches(posix)
  if not posix then return false end
  -- This MR3020 installation uses POSIX /tmp/TZ. A zoneinfo-based target is
  -- conservatively unconfirmed here, never reported as successful by assumption.
  local f=io.open(runtime,'rb');if not f then return false end
  local text=f:read(1024);f:close();return text and text:gsub('[\r\n]+$','')==posix
 end
 function backend.close()
  local it=fs.dir(path);if it then for name in it do assert(name=='system','unexpected staging file');assert(fs.unlink(path..'/'..name))end end
  assert(fs.rmdir(path))
 end
 return backend
end
function M.run(zone,revision)
 local lock,backend
 local ok,result=pcall(function()
  lock=require('schoolbell.media_fs').new('/etc/schoolbell-editor')
  backend=M.system();return M.request(backend,zone,revision)
 end)
 if backend then pcall(backend.close)end
 if lock then pcall(lock.close)end
 return ok and result or {ok=false,code='unavailable'}
end
return M
