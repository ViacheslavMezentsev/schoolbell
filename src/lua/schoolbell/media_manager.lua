-- Isolated prepared-media manager. No scheduling, audio, upload or core calls.
local C=require('schoolbell.media_codec');local J=require('modbus.json_strict')
local M={};local names={'catalog.json','settings.json','schedules.json','plans.json'}
local function check(v,msg)assert(v,msg)end
local function id(x)return type(x)=='string' and #x>0 and #x<=64 and x:match('^[A-Za-z0-9_-]+$')end
function M.new(fs,options)
 options=options or {};local safe=options.ownership_safe or function()return false end
 local hook=options.checkpoint or function()end;local pins={};local closed=false;local blocked=false
 local function alive()check(not closed,'closed');check(safe()==true,'ownership_unknown')end
 local function point(x)hook(x)end
 for _,d in ipairs({'objects','snapshots','staging'})do fs.mkdir(d)end
 fs.sync('');local api={}
 local function catalog(raw)
  local t=C.decode(raw);C.fields(t,{'melodies'});check(J.kind(t.melodies)=='array','melodies')
  local ids,refs,count={},{},0
  for _,m in ipairs(t.melodies)do
   C.fields(m,m.title~=nil and {'id','name','title','revisions'} or {'id','name','revisions'});if m.title~=nil then check(type(m.title)=='string' and #m.title>0 and #m.title<=96 and not m.title:find('[%c]'),'title')end;check(id(m.id) and not ids[m.id] and type(m.name)=='string' and #m.name<=256,'melody');ids[m.id]=true
   check(J.kind(m.revisions)=='array' and #m.revisions>0,'revisions');local seen={}
   for _,v in ipairs(m.revisions)do
    C.fields(v,{'revision','source','size_bytes','audio'});C.fields(v.audio,{'format','duration_ms','sample_rate_hz','channels'})
    check(C.hex(v.revision,64) and not seen[v.revision],'revision');seen[v.revision]=true
    -- Prepared-user-object mode only; bundled lookup/MP3 validation are not fabricated.
    check(v.source=='user' and C.integer(v.size_bytes,1,524288),'prepared user media')
    local a=v.audio;check(a.format=='mp3' and C.integer(a.duration_ms,1,60000) and C.integer(a.sample_rate_hz,8000,48000) and C.integer(a.channels,1,2),'audio')
    if refs[v.revision]then check(refs[v.revision].size_bytes==v.size_bytes,'conflicting size')end
    refs[v.revision]=v;count=count+1
   end
  end
  return refs
 end
 local function documents(docs)
  C.fields(docs,names);local total=0
  for _,n in ipairs(names)do check(type(docs[n])=='string' and #docs[n]<=16384,'decoder bound');C.decode(docs[n]);total=total+#docs[n]end
  check(total<=262144,'metadata quota');local refs=catalog(docs['catalog.json'])
  -- Prepared bundle dependency lists, not a replacement calendar/settings schema.
  local cat=C.decode(docs['catalog.json']);local pairs_by_id={}
  for _,m in ipairs(cat.melodies)do for _,v in ipairs(m.revisions)do pairs_by_id[m.id..':'..v.revision]=true end end
  for _,file in ipairs({'schedules.json','plans.json'})do local v=C.decode(docs[file]);C.fields(v,{'references'});check(J.kind(v.references)=='array','references')
   for _,ref in ipairs(v.references)do C.fields(ref,{'id','revision'});check(id(ref.id) and C.hex(ref.revision,64) and pairs_by_id[ref.id..':'..ref.revision],'missing media reference')end
  end
  return refs,total
 end
 local function snapshot(ref,expected)
  C.fields(ref,{'snapshot','sha256'});check(C.hex(ref.snapshot,32) and C.hex(ref.sha256,64),'snapshot ref')
  local base='snapshots/'..ref.snapshot..'/';local raw=fs.read(base..'snapshot.json',16384)
  check(raw and C.sha(raw)==ref.sha256,'snapshot hash');local d=C.decode(raw)
  C.fields(d,{'storage_version','operation_id','generation','files'})
  check(d.storage_version==1 and d.operation_id==ref.snapshot and C.integer(d.generation,1,2147483647),'descriptor')
  if expected then check(d.generation==expected,'generation mismatch')end
  check(J.kind(d.files)=='array' and #d.files==4,'file count');local docs,seen,total={},{},#raw
  for _,v in ipairs(d.files)do
   C.fields(v,{'name','size_bytes','sha256'});local allowed=false;for _,n in ipairs(names)do if n==v.name then allowed=true end end
   check(allowed and not seen[v.name] and C.integer(v.size_bytes,1,16384) and C.hex(v.sha256,64),'file descriptor');seen[v.name]=true
   local bytes=fs.read(base..v.name,16384);check(bytes and #bytes==v.size_bytes and fs.hash(base..v.name)==v.sha256,'metadata hash');docs[v.name]=bytes;total=total+#bytes
  end
  check(total<=262144,'snapshot quota');local refs=documents(docs)
  for h,v in pairs(refs)do local st=fs.stat('objects/'..h);check(st and st.type=='reg' and st.size==v.size_bytes and fs.hash('objects/'..h)==h,'object hash')end
  return {descriptor=d,documents=docs,objects=refs,ref=ref}
 end
 local function pointer(file)local raw=fs.read(file,4096);if not raw then return nil end;return C.parse(raw)end
 local function candidate(p)
  if not p then return nil end;return snapshot(p.current,p.generation)
 end
 function api.recover()
  local ok,result=pcall(function()
   alive();local good,p=pcall(pointer,'current.json')
   if good and p then local valid,s=pcall(candidate,p);if valid then blocked=false;return {state='ready',generation=p.generation,operation_id=s.descriptor.operation_id,pointer=p}end end
   blocked=true
   -- Previous from an intact current pointer, then saved recovery current/previous.
   local refs={};if good and p and p.previous~=C.null then refs[#refs+1]=p.previous end
   local rg,rp=pcall(pointer,'recovery.json');if rg and rp then refs[#refs+1]=rp.current;if rp.previous~=C.null then refs[#refs+1]=rp.previous end end
   for _,ref in ipairs(refs)do local valid,s=pcall(snapshot,ref);if valid then return {state='paused',generation=s.descriptor.generation,operation_id=s.descriptor.operation_id,ref=ref}end end
   if good and not p and rg and not rp and #fs.list('snapshots')==0 and #fs.list('objects')==0 then return {state='empty'}end
   return {state='recovery_required'}
  end)
  if not ok then blocked=true;return {state='recovery_required',error=tostring(result)}end;return result
 end
 local function replace(file,bytes,label)
  local tmp='staging/'..file..'.tmp';if fs.stat(tmp)then fs.unlink(tmp)end
  fs.write(tmp,bytes);point(label..'_write');fs.sync(tmp);point(label..'_file_sync')
  fs.rename(tmp,file);point(label..'_rename');fs.sync('staging');fs.sync('');point(label..'_dir_sync')
 end
 local function object_bytes()
  local sum=0;for _,h in ipairs(fs.list('objects'))do check(C.hex(h,64),'unexpected object');sum=sum+assert(fs.stat('objects/'..h)).size end
  for _,f in ipairs(fs.list('staging'))do local st=assert(fs.stat('staging/'..f));check(st.type=='reg','staging type');if f:sub(-5)=='.part' then sum=sum+st.size end end
  return sum
 end
 function api.commit(op,expected,docs,imports,initialize)
  local publishing=false;local committed=false;local result
  local ok,why=pcall(function()
   alive();check(C.hex(op,32) and C.integer(expected,0,2147483646),'arguments')
   local state=api.recover();check(state.state=='ready' or (initialize==true and state.state=='empty' and expected==0),'needs_recovery')
   if state.state=='ready' and expected~=state.generation then result={status='conflict'};return end
   check(not fs.stat('snapshots/'..op),'operation exists');local refs,total=documents(docs);imports=imports or {}
   local incoming=0;for h,v in pairs(refs)do if not fs.stat('objects/'..h)then check(type(imports[h])=='string','missing import');incoming=incoming+v.size_bytes end end
   local free,capacity=fs.space()
   check(free>=incoming+total+8192+math.max(524288,math.ceil(capacity/10)),'space reserve')
   point('validated')
   for h,v in pairs(refs)do
    if not fs.stat('objects/'..h)then
     local tmp='staging/'..h..'.part';check(not fs.stat(tmp),'partial upload requires cleanup')
     check(fs.copy(imports[h],tmp,524288)==v.size_bytes and fs.hash(tmp)==h,'import hash');point('object_write')
     fs.sync(tmp);point('object_file_sync');fs.rename(tmp,'objects/'..h);point('object_rename');fs.sync('staging');fs.sync('objects');point('object_dir_sync')
    end
    check(assert(fs.stat('objects/'..h)).size==v.size_bytes and fs.hash('objects/'..h)==h,'existing object')
   end
   local base='snapshots/'..op;fs.mkdir(base);local desc={storage_version=1,operation_id=op,generation=expected+1,files={}}
   for _,n in ipairs(names)do fs.write(base..'/'..n,docs[n]);point('metadata_write_'..n);fs.sync(base..'/'..n);point('metadata_sync_'..n);desc.files[#desc.files+1]={name=n,size_bytes=#docs[n],sha256=fs.hash(base..'/'..n)}end
   local raw=C.encode(desc);check(total+#raw<=262144,'metadata quota');fs.write(base..'/snapshot.json',raw);point('snapshot_write');fs.sync(base..'/snapshot.json');point('snapshot_file_sync');fs.sync(base);fs.sync('snapshots');point('snapshot_dir_sync')
   local ref={snapshot=op,sha256=C.sha(raw)};snapshot(ref,expected+1)
   local old=state.pointer
   if old then replace('recovery.json',C.encode(old),'recovery')end
   local new={generation=expected+1,current=ref,previous=old and old.current or C.null}
   local bytes=C.seal(new);publishing=true;replace('current.json',bytes,'current');committed=true;blocked=false
   result={status='saved',generation=expected+1,operation_id=op};point('saved')
  end)
  if not ok then
   if committed then return {status='saved',generation=expected+1,operation_id=op,warning=tostring(why)}end
   blocked=publishing or tostring(why):find('needs_recovery',1,true)~=nil
   return {status=blocked and 'needs_recovery' or 'rejected',error=tostring(why)}
  end
  return result
 end
 function api.lookup(op)
  alive();check(C.hex(op,32),'operation');for _,file in ipairs({'current.json','recovery.json'})do
   local ok,p=pcall(pointer,file);if ok and p then for _,ref in ipairs({p.current,p.previous})do
    if ref~=C.null and ref.snapshot==op then local valid,s=pcall(snapshot,ref);if valid then return {state='retained',generation=s.descriptor.generation,operation_id=op}end end
   end end
  end;return {state='unknown'} -- never claims rejected from absence
 end
 function api.hold(hash)
  alive();check(C.hex(hash,64) and fs.stat('objects/'..hash),'object');pins[hash]=(pins[hash]or 0)+1
  local held=true;return function()if held then held=false;pins[hash]=pins[hash]-1 end end
 end
 function api.cleanup()
  local ok,why=pcall(function()
   alive();local state=api.recover();check(state.state=='ready' and not blocked,'needs_recovery');local p=state.pointer
   local keep,objects={},{}
   for _,ref in ipairs({p.current,p.previous})do if ref~=C.null then local s=snapshot(ref);keep[ref.snapshot]=true;for h in pairs(s.objects)do objects[h]=true end end end
   -- Converge both pointers durably BEFORE deleting the formerly retained generation.
   replace('recovery.json',C.encode(p),'cleanup_recovery')
   for _,op in ipairs(fs.list('snapshots'))do
    check(C.hex(op,32),'snapshot name');if not keep[op]then
     local base='snapshots/'..op;for _,n in ipairs(fs.list(base))do local allowed=n=='snapshot.json';for _,k in ipairs(names)do if k==n then allowed=true end end;check(allowed,'unknown snapshot file');fs.unlink(base..'/'..n);point('cleanup_file')end
     fs.rmdir(base);point('cleanup_snapshot')
    end
   end
   fs.sync('snapshots')
   for _,h in ipairs(fs.list('objects'))do check(C.hex(h,64),'object name');if not objects[h] and not (pins[h] and pins[h]>0)then fs.unlink('objects/'..h);point('cleanup_object')end end
   fs.sync('objects')
   for _,f in ipairs(fs.list('staging'))do check(C.hex(f:sub(1,64),64) and f:sub(65)=='.part' or f=='current.json.tmp' or f=='recovery.json.tmp','staging name');fs.unlink('staging/'..f)end;fs.sync('staging');point('cleaned')
  end)
  return ok and {status='cleaned'} or {status='cleanup_failed',error=tostring(why)}
 end
 function api.close()for _,n in pairs(pins)do check(n==0,'live leases')end;fs.close();closed=true end
 return api
end
return M
