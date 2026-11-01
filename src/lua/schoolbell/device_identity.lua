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
 local ok,board=pcall(get,'/tmp/sysinfo/board_name',96)
 if ok and (board=='tplink,tl-mr3020-v3' or board=='tplink_tl-mr3020-v3')then
  local known,position=pcall(get,'/tmp/switch_position',16)
  local names={['3g']='3G/4G',wisp='WISP',ap='AP'}
  if known and names[position]then result.switch_state='ready';result.position=names[position]end
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
