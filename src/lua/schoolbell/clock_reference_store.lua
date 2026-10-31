-- Inject open(): a private, exclusively locked FS handle. Never opens a real path.
-- FS operations throw on failure (or return false); close releases the writer lock.
local C=require('schoolbell.clock_reference')
local M={name='clock-reference.json',temporary='clock-reference.next'}
function M.new(open)
 assert(type(open)=='function');local api={}
 local function read(fs)
  local raw=fs.read(M.name,C.max_bytes)
  if raw==nil then return nil,'empty' end
  return C.decode(raw)
 end
 local function session(fn)
  local fs;local ok,result=pcall(function()fs=assert(open());return fn(fs)end)
  local closed=true;if fs then closed=pcall(function()assert(fs.close()~=false,'close')end)end
  if not ok or not closed then return {ok=false,code='storage_error'}end
  return result
 end
 function api.load()return session(function(fs)local data,rev=read(fs);return {ok=true,data=data,revision=rev}end)end
 function api.save(data,expected)
  local ok,raw,revision=pcall(C.encode,data);if not ok then return {ok=false,code='invalid_reference'}end
  return session(function(fs)
   local _,current=read(fs);if current~=expected then return {ok=false,code='conflict'}end
   if fs.stat(M.temporary)then assert(fs.unlink(M.temporary)~=false,'unlink')end
   assert(fs.write(M.temporary,raw)~=false,'write')
   assert(fs.sync(M.temporary)~=false,'file sync')
   assert(fs.rename(M.temporary,M.name)~=false,'rename')
   assert(fs.sync('')~=false,'directory sync')
   assert(fs.read(M.name,C.max_bytes)==raw,'verify')
   return {ok=true,revision=revision}
  end)
 end
 return api
end
return M
