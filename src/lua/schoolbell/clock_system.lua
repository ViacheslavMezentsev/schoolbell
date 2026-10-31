-- Explicit host/system ports only. No default directory, timer or executor hookup.
local Store=require('schoolbell.clock_reference_store')
local M={}
function M.new(root,context,native)
 assert(type(context)=='function','context provider required')
 native=native or require('schoolbell.clock_linux')
 local mono_res,utc_res=native.resolution()
 assert(type(mono_res)=='number' and mono_res>0 and mono_res<=1 and type(utc_res)=='number' and utc_res>0 and utc_res<=1,'resolution')
 local function open()
  local h=native.open(root);local fs={}
  for _,method in ipairs({'read','stat','unlink','write','sync','rename','close'})do
   local key=method;fs[key]=function(...)return h[key](h,...)end
  end
  return fs
 end
 local io={store=Store.new(open),valid_utc=function(ms)return type(ms)=='number' and ms>=0 and ms<=2147483647999 and ms==math.floor(ms)end}
 function io.clock()
  local epoch=context();assert(type(epoch)=='string' and #epoch>0 and #epoch<=256,'context')
  local before,utc,after=native.sample()
  assert(context()==epoch,'context changed while sampling')
  return {before_ms=before,utc_ms=utc,after_ms=after,context=epoch}
 end
 return io
end
return M
