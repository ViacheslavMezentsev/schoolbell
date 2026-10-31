-- Trusted private root only; not a hostile-filesystem sandbox.
local M={};local active={}
function M.new(root,host,restore_owner)
 assert(type(root)=='string' and root:match('^/[%w_./-]+$') and not root:find('..',1,true) and not root:find('//',1,true) and not root:find('/./',1,true) and root:sub(-1)~='/','root')
 local b
 if host then b=host else
  local n=require('nixio');local fs=require('nixio.fs')
  b={mkdir=function(p)return fs.mkdir(p,700)end,rename=fs.rename,unlink=fs.unlink,rmdir=fs.rmdir,
   stat=function(p)local s=fs.lstat(p);if s then return {type=s.type,size=s.size,uid=s.uid,mode=tonumber(tostring(s.modedec),8)%512}end end,
   list=function(p)local t={};local it=fs.dir(p);if not it then return nil end;for x in it do assert(#t<512,'directory quota');t[#t+1]=x end;return t end,
   sync=function(p)local f=assert(n.open(p,n.open_flags('rdonly')+131072+524288));local ok=f:sync();local closed=f:close();return ok and closed end,
   space=function(p)local s=assert(fs.statvfs(p));return s.bavail*s.frsize,s.blocks*s.frsize end,
   lock=function(p)local f=assert(n.open(p,n.open_flags('rdwr','creat')+131072+524288,600));if not f:lock('tlock')then f:close();return nil end;return f end,
   unlock=function(f)return f:close()end}
 end
 local s=assert(b.stat(root),'root absent');assert(s.type=='dir' and s.mode%64==0,'root must be private')
 assert(restore_owner==true or not b.stat(root..'/restore.pending'),'restore_pending')
 assert(restore_owner=='import' or not b.stat(root..'/import.pending'),'import_pending')
 assert(not active[root],'busy');local lock=assert(b.lock(root..'/.lock'),'busy');if (restore_owner~=true and b.stat(root..'/restore.pending'))or(restore_owner~='import' and b.stat(root..'/import.pending'))then b.unlock(lock);error('recovery_required')end;active[root]=true
 local self={}
 local function path(rel)
  assert(rel=='' or (rel:match('^[%w_./-]+$') and rel:sub(1,1)~='/' and not rel:find('..',1,true)),'relative path')
  local p=root
  for part in rel:gmatch('[^/]+')do p=p..'/'..part;local st=b.stat(p);assert(not st or st.type=='reg' or st.type=='dir','special file')end
  return p
 end
 function self.stat(p)return b.stat(path(p))end
 function self.mkdir(p)local q=path(p);local st=b.stat(q);if st then assert(st.type=='dir')else assert(b.mkdir(q))end end
 function self.list(p)return assert(b.list(path(p)))end
 function self.read(p,max)local q=path(p);local st=b.stat(q);if not st then return nil end;assert(st.type=='reg' and st.size<=max,'file size');local f=assert(io.open(q,'rb'));local data=f:read(max+1);local ok=f:close();assert(ok and data and #data==st.size,'read');return data end
 function self.open_read(p)local q=path(p);local st=assert(b.stat(q));assert(st.type=='reg');return assert(io.open(q,'rb'))end
 function self.open_write(p)local q=path(p);assert(not b.stat(q),'exists');return assert(io.open(q,'wb'))end
 function self.write(p,data)local q=path(p);assert(not b.stat(q),'exists');local f=assert(io.open(q,'wb'));local ok=f:write(data);local closed=f:close();assert(ok and closed,'write')end
 function self.sync(p)assert(b.sync(path(p)),'sync')end
 function self.rename(a,z)assert(b.rename(path(a),path(z)),'rename')end
 function self.unlink(p)assert(b.unlink(path(p)),'unlink')end
 function self.rmdir(p)assert(b.rmdir(path(p)),'rmdir')end
 function self.space()return b.space(root)end
 local function hash(q)
  -- q contains only the validated private root/path alphabet, never shell syntax.
  local f=assert(io.popen('sha256sum '..q,'r'));local out=f:read('*a');local ok=f:close();assert(ok,'hash process');local h=out and out:match('^([0-9a-f]+)%s');assert(h and #h==64,'hash');return h
 end
 function self.hash(p)return hash(path(p))end
 function self.copy(source,p,maximum)
  assert(type(source)=='string' and source:match('^/[%w_./-]+$') and not source:find('..',1,true),'source')
  local st=assert(b.stat(source));assert(st.type=='reg' and st.size<=maximum,'source size')
  local q=path(p);assert(not b.stat(q),'exists');local a=assert(io.open(source,'rb'));local z=io.open(q,'wb');if not z then a:close();error('copy open')end
  local count=0;local ok,why=pcall(function()while true do local c=a:read(16384);if not c then break end;count=count+#c;assert(count<=maximum,'copy size');assert(z:write(c))end end)
  local ca,cz=a:close(),z:close();assert(ok and ca and cz and count==st.size,why or 'copy');return count
 end
 function self.close()if lock then local h=lock;lock=nil;active[root]=nil;assert(b.unlock(h),'unlock')end end
 return self
end
return M
