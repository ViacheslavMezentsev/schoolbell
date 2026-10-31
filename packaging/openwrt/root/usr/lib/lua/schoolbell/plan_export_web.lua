local M={};local C=require('schoolbell.media_codec');local F=require('schoolbell.media_fs')
local A=require('schoolbell.automatic_store');local L=require('schoolbell.media_library')
local function zone()
 local b=require('schoolbell.timezone').system();local ok,v=pcall(function()
  local s=b.read();assert(not s.pending and b.zones()[s.zone]==s.posix and b.matches(s.posix),'timezone');return {name=s.zone,posix=s.posix}
 end);b.close();assert(ok,v);return v
end
function M.download(selected,revision,start,emit)
 local fs=require('nixio.fs');local gate=require('schoolbell.sound_test').lock
 if not fs.mkdir(gate,700)then return {ok=false,code='busy'}end
 local editor,media,lib,work,root,file;local held=true
 local function release()
  if lib then lib.close();lib=nil;media=nil elseif media then media.close();media=nil end
  if editor then editor.close();editor=nil end
  if held then assert(fs.rmdir(gate));held=false end
 end
 local ok,value=require('luci.util').copcall(function()
  local p=assert(io.popen('mktemp -d /tmp/schoolbell-plan-export.XXXXXX'));root=p:read('*l');assert(p:close());assert(root and root:match('^/tmp/schoolbell%-plan%-export%.[A-Za-z0-9]+$'))
  work=F.new(root);editor=F.new(A.root);media=F.new(L.root);lib=L.open(media,L.root,function()return true end)
  local f=assert(io.open('/usr/share/schoolbell-editor/VERSION'));local version=f:read('*l');f:close()
  local env={version=version,timezone=zone,open=function(path)return assert(io.open(path,'rb'))end,inspect=function(path)
   local p=assert(io.popen('sha256sum '..path));local hash=(p:read('*l')or''):match('^[a-f0-9]+');assert(p:close());local st=assert(fs.stat(path));return hash,st.size
  end}
  local meta=require('schoolbell.plan_export_bundle').build(editor,lib,work,env,selected,revision)
  release() -- A slow browser never owns editor/media locks.
  file=work.open_read('plan.sbp');start(meta)
  while true do local chunk=file:read(16384);if not chunk then break end;emit(chunk)end
  assert(file:close());file=nil;return {ok=true}
 end)
 if file then pcall(function()file:close()end)end
 local released=pcall(release)
 local cleaned=true
 if work then
  cleaned=pcall(function()for _,name in ipairs(work.list(''))do if name~='.lock'then assert(name=='plan.sbp'or name:match('^hash%-%d+$'));work.unlink(name)end end end)
  cleaned=pcall(work.close)and cleaned
 end
 if root then cleaned=pcall(function()if fs.stat(root..'/.lock')then assert(fs.unlink(root..'/.lock'))end;assert(fs.rmdir(root))end)and cleaned end
 if ok and released and cleaned then return value end
 local text=tostring(value);local code='storage_unavailable'
 for _,v in ipairs({'busy','conflict','selection','dependency','checksum','timezone','space','automatic_enabled','recovery_required','size'})do if text==v or text:match(': '..v..'$')then code=v;break end end
 return {ok=false,code=code}
end
return M
