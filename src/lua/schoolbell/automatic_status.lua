-- Private, worker-authored exact-byte witness. Never validates a new plan in GET.
local C=require('schoolbell.media_codec');local M={root='/tmp/schoolbell-status-cache',limit=24576}
function M.pack(raw,status,boot)
 assert(raw==nil or type(raw)=='string' and #raw<=16384)
 local header=C.encode({version=1,present=raw~=nil,boot=boot,status=status});assert(#header<=8191)
 return header..'\n'..(raw or '')
end
function M.resolve(current,blob,now,boot)
 if type(blob)~='string' or #blob>M.limit then return {ok=false,state='unavailable'}end
 local split=blob:find('\n',1,true);if not split or split>8192 then return {ok=false,state='unavailable'}end
 local ok,h=pcall(C.decode,blob:sub(1,split-1))
 if not ok or type(h)~='table' or h.version~=1 or type(h.present)~='boolean' or h.boot~=boot or type(h.status)~='table' then return {ok=false,state='unavailable'}end
 local body=blob:sub(split+1);local s=h.status
 if not h.present and #body~=0 then return {ok=false,state='unavailable'}end
 if (current~=nil)~=h.present or (current or '')~=body then return {ok=true,state='waiting'}end
 if type(s.uptime)~='number' or s.uptime~=math.floor(s.uptime) or now<s.uptime or now-s.uptime>40 then return {ok=true,state='waiting'}end
 if type(s.ok)~='boolean' or type(s.state)~='string' or #s.state>64 then return {ok=false,state='unavailable'}end
 if s.ok and (type(s.enabled)~='boolean' or not C.integer(s.generation,0,2147483647))then return {ok=false,state='unavailable'}end
 return s
end
local function private_root(create)
 local fs=require('nixio.fs');local s=fs.lstat(M.root)
 if not s and create then assert(fs.mkdir(M.root,700));s=fs.lstat(M.root)end
 assert(s and s.type=='dir' and s.uid==0 and tonumber(tostring(s.modedec),8)%64==0,'private status root')
 return fs
end
function M.invalidate()
 local fs=private_root(true);local h=require('schoolbell.media_fs').new(M.root)
 local ok,why=pcall(function()for _,name in ipairs({'snapshot','snapshot.next'})do if h.stat(name)then h.unlink(name)end end end)
 h.close();assert(ok,why)
end
function M.publish(raw,status,boot)
 private_root(true);local h=require('schoolbell.media_fs').new(M.root)
 local ok,why=pcall(function()
  if h.stat('snapshot.next')then h.unlink('snapshot.next')end
  h.write('snapshot.next',M.pack(raw,status,boot));h.rename('snapshot.next','snapshot')
 end)
 h.close();assert(ok,why)
end
function M.read(current)
 local ok,result=pcall(function()
  local fs=private_root(false);local st=fs.lstat(M.root..'/snapshot');assert(st and st.type=='reg' and st.uid==0 and st.size<=M.limit)
  local f=assert(io.open(M.root..'/snapshot','rb'));local blob=f:read(M.limit+1);assert(f:close())
  local f=assert(io.open('/proc/uptime','r'));local now=tonumber(f:read(64):match('^[%d.]+'));f:close()
  local f=assert(io.open('/proc/sys/kernel/random/boot_id','rb'));local boot=f:read(64);f:close()
  return M.resolve(current,blob,now,boot)
 end)
 return ok and result or {ok=false,state='unavailable'}
end
return M
