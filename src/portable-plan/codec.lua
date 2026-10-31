-- Isolated SBPLAN1 byte codec. Not installed, no filesystem/network/player calls.
-- Output chunks are tentative until success; caller owns disposal on any error.
local J=require('modbus.json_strict')
local C=require('schoolbell.media_codec')
local M={magic='SBPLAN1\n',maximum=2125906,chunk=16384}
local function need(ok,code) if not ok then error(code,0) end end
local function object(v,keys)
 need(J.kind(v)=='object','format');local allowed={}
 for _,k in ipairs(keys)do allowed[k]=true;need(v[k]~=nil,'format')end
 for k in pairs(v)do need(allowed[k],'format')end
end
local function arr(v,lo,hi)need(J.kind(v)=='array' and #v>=lo and #v<=hi,'format')end
local function ascii(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('[^\32-\126]') end
local function id(v)return type(v)=='string' and #v>0 and #v<=64 and v:match('^[A-Za-z0-9_-]+$')end
local function title(v)return type(v)=='string' and #v>0 and #v<=96 and not v:find('[%z\1-\31\127]') and v:find('%S')end
local function json(raw,max)
 need(type(raw)=='string' and #raw>0 and #raw<=max,'size')
 local v=J.decode(raw);need(v~=nil,'format');return v
end
function M.manifest(raw)
 local m=json(raw,16384);object(m,{'format','exporter','timezone','files','media'})
 need((m.format=='schoolbell-plan/1' or m.format=='schoolbell-plan/2'),'format')
 object(m.exporter,{'name','version'})
 need(m.exporter.name=='schoolbell-device' or m.exporter.name=='schoolbell-pages','format')
 local v=m.exporter.version;need(ascii(v,32),'format')
 local a,b,c=v:match('^(%d+)%.(%d+)%.(%d+)$');need(a and (#a==1 or a:sub(1,1)~='0') and (#b==1 or b:sub(1,1)~='0') and (#c==1 or c:sub(1,1)~='0'),'format')
 object(m.timezone,{'name','posix'});need(ascii(m.timezone.name,64) and ascii(m.timezone.posix,256),'format')
 arr(m.files,1,m.format=='schoolbell-plan/1' and 9 or math.huge);arr(m.media,1,m.format=='schoolbell-plan/1' and 14 or math.huge)
 local files,total,audio,prior={},82+#raw,0,''
 for i,f in ipairs(m.files)do
  object(f,{'name','size_bytes','sha256'})
  need(C.integer(f.size_bytes,1,i==1 and 12288 or 524288),'size')
  need(C.hex(f.sha256,64),'format')
  if i==1 then need(f.name=='calendar.json','format')
  else
   need(f.name=='media/'..f.sha256..'.mp3' and f.sha256>prior,'format');prior=f.sha256;audio=audio+f.size_bytes
  end
  need(not files[f.name],'format');files[f.name]=f;total=total+f.size_bytes
 end
 need(audio<=2097152 and total<=M.maximum,'size')
 local ids,bundled,used={},{},{}
 for _,v in ipairs(m.media)do
  need(J.kind(v)=='object','format')
  object(v,{'id','title','source','size_bytes','sha256',v.source=='bundled' and 'bundled_id' or 'file'})
  need(id(v.id) and not ids[v.id] and title(v.title),'format');ids[v.id]=true
  need(C.integer(v.size_bytes,1,524288),'size');need(C.hex(v.sha256,64),'format')
  if v.source=='bundled' then
   need(({test=true,['0']=true,['1']=true,['2']=true,['3']=true,['4']=true})[v.bundled_id] and not bundled[v.bundled_id],'format');bundled[v.bundled_id]=true
  else
   need(v.source=='user' and v.file=='media/'..v.sha256..'.mp3','format')
   local f=files[v.file];need(f and f.sha256==v.sha256 and f.size_bytes==v.size_bytes,'dependency');used[v.file]=true
  end
 end
 for i=2,#m.files do need(used[m.files[i].name],'dependency')end
 return m,total
end
local function reader(source)
 local buffer,ended,total='',false,0
 local function fill()
  local chunk,err=source();need(not err,'io')
  if chunk==nil then ended=true;return end
  need(type(chunk)=='string' and #chunk>0 and #chunk<=M.chunk,'chunk')
  total=total+#chunk;need(total<=M.maximum,'size');buffer=buffer..chunk
 end
 local function take(n)
  while #buffer<n and not ended do fill()end
  need(#buffer>=n,'truncated');local s=buffer:sub(1,n);buffer=buffer:sub(n+1);return s
 end
 local function eof()
  need(#buffer==0,'trailing');if not ended then fill()end
  need(ended and #buffer==0,'trailing');return total
 end
 return take,eof
end
function M.decode(source,hash_factory,sink)
 local take,eof=reader(source)
 need(take(8)==M.magic,'format');local line=take(9)
 need(line:match('^%d%d%d%d%d%d%d%d\n$'),'format')
 local n=tonumber(line);need(n>=1 and n<=16384,'size')
 local h=take(65);need(h:sub(65)=='\n' and C.hex(h:sub(1,64),64),'format')
 local raw=take(n);need(C.sha(raw)==h:sub(1,64),'checksum')
 local m,total=M.manifest(raw);local calendar
 for i,f in ipairs(m.files)do
  local hash=hash_factory();local left=f.size_bytes;local pieces={}
  while left>0 do
   local chunk=take(math.min(left,M.chunk));left=left-#chunk
   need(hash:update(chunk)~=false,'io')
   if i==1 then pieces[#pieces+1]=chunk end
   if sink then need(sink(f.name,chunk)~=false,'io')end
  end
  need(hash:finish()==f.sha256,'checksum')
  if i==1 then calendar=table.concat(pieces);json(calendar,12288)end
 end
 need(eof()==total,'size')
 return {manifest=m,calendar=calendar,bytes=total,admitted=false}
end
function M.encode(raw,source_for,hash_factory,emit)
 local m,total=M.manifest(raw)
 need(emit(M.magic..string.format('%08d\n',#raw)..C.sha(raw)..'\n')~=false,'io')
 need(emit(raw)~=false,'io')
 for i,f in ipairs(m.files)do
  local take,eof=reader(source_for(f.name));local hash=hash_factory();local left=f.size_bytes;local pieces={}
  while left>0 do
   local chunk=take(math.min(left,M.chunk));left=left-#chunk
   need(hash:update(chunk)~=false,'io');need(emit(chunk)~=false,'io')
   if i==1 then pieces[#pieces+1]=chunk end
  end
  need(eof()==f.size_bytes,'size');need(hash:finish()==f.sha256,'checksum')
  if i==1 then json(table.concat(pieces),12288)end
 end
 return total
end
return M
