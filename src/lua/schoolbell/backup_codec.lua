-- Flat framed backup, not a tar extractor. Metadata <=16 KiB; audio stays streamed.
local C=require('schoolbell.media_codec');local J=require('modbus.json_strict');local L=require('schoolbell.media_library')
local M={magic='SBBACKUP1\n',maximum=2162816,stage='restore-stage'}
local fixed={['draft.json']=true,['controls.json']=true,['catalog.json']=true}
function M.safe_name(name)return fixed[name] or (type(name)=='string' and #name==68 and C.hex(name:sub(1,64),64) and name:sub(65)=='.mp3')end
function M.manifest(raw)
 local m=C.decode(raw);C.fields(m,{'format','timezone','files'})
 assert((m.format=='schoolbell-backup/1' or m.format=='schoolbell-backup/2') and type(m.timezone)=='string' and #m.timezone<=256,'format/timezone')
 assert(J.kind(m.files)=='array' and #m.files>=3 and (m.format~='schoolbell-backup/1' or #m.files<=11),'files')
 local total,seen=0,{}
 for i,v in ipairs(m.files)do
  C.fields(v,{'name','size_bytes','sha256'});assert(M.safe_name(v.name) and not seen[v.name],'file name');seen[v.name]=true
  if i<=3 then assert(v.name==({'draft.json','controls.json','catalog.json'})[i],'metadata order')else assert(not fixed[v.name],'object order')end
  assert(C.integer(v.size_bytes,1,i<=3 and 16384 or 524288) and C.hex(v.sha256,64),'file bounds')
  if i>3 then assert(v.sha256==v.name:sub(1,64),'object name/hash');total=total+v.size_bytes end
 end
 assert(total<=2097152,'media quota');return m,total
end
function M.catalog(raw)
 local cat=C.decode(raw);C.fields(cat,{'melodies'});assert(J.kind(cat.melodies)=='array','catalog')
 local ids,objects={},{}
 for _,m in ipairs(cat.melodies)do
  C.fields(m,m.title~=nil and {'id','name','title','revisions'} or {'id','name','revisions'})
  assert(L.editable(m.id) and not ids[m.id] and type(m.name)=='string' and #m.name>0 and #m.name<=96 and not m.name:find('[%c]'),'melody');ids[m.id]=true
  if m.title~=nil then assert(type(m.title)=='string' and #m.title>0 and #m.title<=96 and not m.title:find('[%c]'),'title')end
  assert(J.kind(m.revisions)=='array' and #m.revisions==1,'one current revision')
  local v=m.revisions[1];C.fields(v,{'revision','source','size_bytes','audio'});C.fields(v.audio,{'format','duration_ms','sample_rate_hz','channels'})
  assert(v.source=='user' and C.hex(v.revision,64) and C.integer(v.size_bytes,1,524288),'revision')
  assert(v.audio.format=='mp3' and C.integer(v.audio.duration_ms,1,60000) and C.integer(v.audio.sample_rate_hz,8000,48000) and C.integer(v.audio.channels,1,2),'audio')
  if objects[v.revision]then assert(C.encode(objects[v.revision])==C.encode(v),'inconsistent object')end;objects[v.revision]=v
 end
 return cat,objects,ids
end
function M.clean(fs)
 if not fs.stat(M.stage)then return end
 for _,name in ipairs(fs.list(M.stage))do assert(M.safe_name(name) or name=='manifest.json' or name=='rollback-draft.json','unexpected staging');fs.unlink(M.stage..'/'..name)end
 fs.rmdir(M.stage);fs.sync('')
end
function M.receive(fs,source,expected,protect)
 assert(C.integer(expected,1,M.maximum),'archive size');M.clean(fs);fs.mkdir(M.stage)
 local buffer='';local received=0;local ended=false
 local function take(n)
  while #buffer<n and not ended do
   local chunk,err=source();assert(not err,'stream error')
   if chunk then assert(type(chunk)=='string' and #chunk>0 and #chunk<=16384,'chunk');received=received+#chunk;assert(received<=expected,'too much data');buffer=buffer..chunk else ended=true end
  end
  if #buffer<n then error('truncated')end;local v=buffer:sub(1,n);buffer=buffer:sub(n+1);return v
 end
 assert(take(#M.magic)==M.magic,'magic');local line=take(9);assert(line:match('^%d%d%d%d%d%d%d%d\n$'),'length')
 local length=tonumber(line);assert(length>0 and length<=16384,'manifest length')
 local hash=take(65);assert(hash:sub(-1)=='\n' and C.hex(hash:sub(1,64),64),'header checksum')
 local raw=take(length);assert(C.sha(raw)==hash:sub(1,64),'manifest checksum');local manifest=M.manifest(raw)
 local declared=#M.magic+9+65+#raw;for _,v in ipairs(manifest.files)do declared=declared+v.size_bytes end;assert(declared==expected,'declared size')
 fs.write(M.stage..'/manifest.json',raw);fs.sync(M.stage..'/manifest.json')
 for _,v in ipairs(manifest.files)do
  local name=M.stage..'/'..v.name;local out=fs.open_write(name)
  local good,why=(protect or pcall)(function()local left=v.size_bytes;while left>0 do local n=math.min(left,16384);assert(out:write(take(n)));left=left-n end end)
  local closed=out:close();assert(good and closed,why or 'write');assert(fs.hash(name)==v.sha256,'file checksum');fs.sync(name)
 end
 if not ended then local chunk,err=source();assert(not err and chunk==nil,'trailing data')end
 assert(#buffer==0 and received==expected,'trailing size');fs.sync(M.stage);fs.sync('');return raw,manifest
end
function M.validate(fs,root,timezone,decode)
 local raw=assert(fs.read(M.stage..'/manifest.json',16384));local manifest=M.manifest(raw);assert(manifest.timezone==timezone,'timezone_mismatch')
 local descriptors={}
 for _,v in ipairs(manifest.files)do local p=M.stage..'/'..v.name;local st=assert(fs.stat(p));assert(st.size==v.size_bytes and fs.hash(p)==v.sha256,'staging checksum');descriptors[v.name]=v end
 local S=require('schoolbell.schedule_store');local draft=assert(S.validate(fs.read(M.stage..'/draft.json',16384)))
 local controls=C.decode(fs.read(M.stage..'/controls.json',16384));C.fields(controls,{'muted','volume_db'});assert(type(controls.muted)=='boolean' and C.integer(controls.volume_db,-60,0),'controls')
 local cat,objects,ids=M.catalog(fs.read(M.stage..'/catalog.json',16384));local count=0
 for hash,v in pairs(objects)do
  local name=hash..'.mp3';assert(descriptors[name] and descriptors[name].size_bytes==v.size_bytes,'missing object')
  local audio=require('schoolbell.mp3').inspect(root..'/'..M.stage..'/'..name);assert(C.encode(audio)==C.encode(v.audio),'audio metadata')
  if decode then decode(root..'/'..M.stage..'/'..name)end;count=count+1
 end
 assert(count==#manifest.files-3,'unreferenced object')
 local function ref(id)assert(not L.editable(id) or ids[id],'missing melody reference')end
 ref(draft.pre_media);ref(draft.manual_media or 'test');for _,s in ipairs(draft.schedules)do for _,row in ipairs(s.rows)do ref(row.media)end end
 return {manifest=manifest,manifest_hash=C.sha(raw),draft=draft,controls=controls,catalog=cat,objects=objects}
end
return M
