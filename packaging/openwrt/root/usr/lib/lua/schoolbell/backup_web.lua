-- One shared player gate, then editor and media filesystem locks, in that order.
local M={};local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local function session(fn)
 local fs=require('nixio.fs');local gate=require('schoolbell.sound_test').lock
 if not fs.mkdir(gate,700)then return {ok=false,code='busy'}end
 local editor,media,backup;local keep=false
 local protect=require('luci.util').copcall
 local ok,result=protect(function()
  local F=require('schoolbell.media_fs');editor=F.new(A.root,nil,true);media=F.new(L.root)
  local f=assert(io.open('/tmp/TZ','rb'));local zone=f:read(257);f:close();assert(zone and #zone<=256,'timezone')
  backup=require('schoolbell.backup').new(editor,media,L.root,{now=os.time(),timezone=zone,protect=protect,
   decode=function(path)require('schoolbell.media_web').decode(path,function()keep=true end)end,
   safe_cleanup=function()return not keep end})
  return fn(backup)
 end)
 local closed=true
 if backup then closed=pcall(backup.close)else
  if media then closed=pcall(media.close) and closed end
  if editor then closed=pcall(editor.close) and closed end
 end
 if not keep and not fs.rmdir(gate)then closed=false end
 if not ok then
  local text=tostring(result);local code='storage'
  for _,v in ipairs({'automatic_enabled','restore_pending','space','timezone_mismatch'})do if text:find(v,1,true)then code=v;break end end
  return {ok=false,code=code}
 end
 if not closed then return {ok=false,code='storage'}end
 return result
end
function M.status()return session(function(b)return b.status()end)end
function M.export(write)return session(function(b)return b.export(write)end)end
function M.restore(operation,source,size)return session(function(b)return b.restore(operation,source,size)end)end
function M.resume(operation)return session(function(b)return b.resume(operation)end)end
return M
