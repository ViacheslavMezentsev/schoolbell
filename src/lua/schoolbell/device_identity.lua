-- Passive header metadata: no commands, GPIO writes or network changes.
local M={}
local function read(path,limit)
 local f=io.open(path,'r');if not f then return nil end
 local s=f:read(limit+1);f:close();if not s or #s>limit then return nil end
 return s:match('^%s*(.-)%s*$')
end
function M.read(server_addr,host)
 host=host or {};local get=host.read or read
 local result={switch_state='unknown'}
 -- Report system-provided labels verbatim; never infer a hardware subrevision.
 local function label(path)
  local ok,value=pcall(get,path,96)
  if not ok or type(value)~='string' or #value>96 then return nil end
  value=value:match('^%s*(.-)%s*$')
  if value=='' or value:find('%c') then return nil end
  return value
 end
 result.model=label('/tmp/sysinfo/model')
 local board=label('/tmp/sysinfo/board_name')
 result.board_name=board
 local ok=board~=nil
 if ok and (board=='tplink,tl-mr3020-v3' or board=='tplink_tl-mr3020-v3')then
  -- MR3020 v3: passive GPIO snapshot; no dependency on slide-switch hotplug.
  local ok_gpio,gpio=pcall(get,'/sys/kernel/debug/gpio',16384)
  if ok_gpio and type(gpio)=='string' and #gpio<=16384 then
   local states={};local invalid=false
   for line in gpio:gmatch('[^\r\n]+')do
    local pin,name,level=line:match('^%s*gpio%-(%d+)%s+%([^|]*|%s*(sw[12])%s*%)%s+in%s+(%a+)%s*$')
    if pin=='41' or pin=='42' then
     if states[pin] or name~=(pin=='41' and 'sw1' or 'sw2') or (level~='hi' and level~='lo')then invalid=true end
     states[pin]=level
    end
   end
   local names={lo_hi='3G/4G',hi_lo='WISP',hi_hi='AP'}
   local position=not invalid and states['41'] and states['42'] and names[states['41']..'_'..states['42']]
   if position then result.switch_state='ready';result.position=position end
  end
 end
 local net,interfaces=pcall(function()return (host.interfaces or require('nixio').getifaddrs)()end)
 if net and type(interfaces)=='table' then
  local lan
  for i,v in ipairs(interfaces)do
   if i>128 then break end
   if type(v)=='table' and (v.family=='inet' or v.family=='inet6') and type(v.addr)=='string' and #v.addr<=64 and v.addr:match('^[%x:%.]+$') and v.name~='lo' then
    if v.addr==server_addr then result.ip=v.addr;break end
    if v.name=='br-lan' and v.family=='inet' then lan=v.addr end
   end
  end
  result.ip=result.ip or lan
 end
 return result
end
return M
