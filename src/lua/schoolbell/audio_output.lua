-- Read-only metadata for the fixed playback endpoint. Never open /dev/dsp.
local M={device='/dev/dsp'}
local function clean(s)
 if type(s)~='string' or #s>256 then return nil end
 s=s:gsub('[%c]',' '):gsub('^%s+',''):gsub('%s+$','')
 return s~='' and s:sub(1,96) or nil
end
function M.read(host)
 local ok,value=pcall(function()
  local fs=host and host.fs or require('nixio.fs')
  local read=host and host.read or function(path)
   local f=io.open(path,'r');if not f then return nil end
   local s=f:read(257);f:close();return s
  end
  local st,err=fs.stat(M.device)
  if not st then return {state=err==2 and 'missing' or 'unknown',device=M.device}end
  if st.type~='chr' or type(st.rdev)~='number' or st.rdev<0 or st.rdev>65535 then return {state='unknown',device=M.device}end
  local link='/sys/dev/char/'..math.floor(st.rdev/256)..':'..(st.rdev%256)
  local path=fs.realpath(link)
  if type(path)~='string' or not path:match('^/sys/devices/') then return {state='unknown',device=M.device}end
  local original=path;local name,controller,model
  for i=1,20 do
   if not name and read(path..'/idVendor') then
    local maker,product=clean(read(path..'/manufacturer')),clean(read(path..'/product'))
    model=product
    if maker and maker:match('^C%-Media')then name='C-Media'
    elseif maker and maker~='Generic' then name=maker
    else name=product end
   end
   local driver=fs.realpath(path..'/driver')
   local kind=type(driver)=='string' and driver:match('/([^/]+)$') or ''
   for _,c in ipairs({'ehci','ohci','xhci','uhci'})do
    if kind==c..'_hcd' or kind==c..'-platform' or kind==c..'-pci' then controller=c:upper()end
   end
   path=path:match('^(.*)/[^/]+$')
   if not path or path=='' or path=='/sys' then break end
  end
  local current=fs.stat(M.device)
  if not current or current.rdev~=st.rdev or current.ino~=st.ino or fs.realpath(link)~=original then return {state='unknown',device=M.device}end
  return {state='ready',device=M.device,name=name,model=model,controller=controller}
 end)
 return ok and value or {state='unknown',device=M.device}
end
return M
