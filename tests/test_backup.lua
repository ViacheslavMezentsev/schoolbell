local F=require('schoolbell.media_fs');local L=require('schoolbell.media_library');local B=require('schoolbell.backup');local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store')
local host=assert(require('schoolbell.media_fs_host'));local root=assert(arg[1]);local cases=0
local function dirs(label)local p=root..'/'..label;assert(host.mkdir(p));assert(host.mkdir(p..'/editor'));assert(host.mkdir(p..'/media'));return p end
local function open(p,hook,zone,protect)
 return B.new(F.new(p..'/editor',host,true),F.new(p..'/media',host),p..'/media',{timezone=zone or 'UTC',now=1792890000,checkpoint=hook,protect=protect})
end
local src=dirs('source');local e=F.new(src..'/editor',host);local data=S.empty();data.manual_media='user1';data.schedules={{id='day',name='Учебный день',rows={{id='one',time='09:00',media='user1',enabled=true,pre=false}}}};for i=2,129 do data.schedules[1].rows[i]={id='r'..i,time='09:00',media='user1',enabled=true,pre=false}end;data.mode='annual';data.plans={{year=2025,schedule_ids={'day'},days='A'..string.rep('.',364)},{id='academic',name='Учебный год 2026–2027',start='2026-09-01',['end']='2027-05-31',schedule_ids={'day'},days='A'..string.rep('.',272)}}
assert(S.save(e,C.encode(data),'empty').ok);e.write('sound-control.json','{"muted":true,"generation":2,"volume_db":-12}');e.close()
local f=F.new(src..'/media',host);local lib=L.open(f,src..'/media',function()return true end);local sample=assert(os.getenv('PWD'))..'/assets/melodies/test.mp3';f.copy(sample,'upload.part',524288);assert(lib.replace('user1','lesson.mp3',0,string.rep('a',32),src..'/media/upload.part',require('schoolbell.mp3').inspect(sample),'Начало урока').status=='saved');f.unlink('upload.part');for i=2,9 do f.copy(sample,'upload.part',524288);assert(lib.replace('user_'..string.format('%032x',i),'copy.mp3',i-1,string.format('%032x',i),src..'/media/upload.part',require('schoolbell.mp3').inspect(sample),'Copy').status=='saved');f.unlink('upload.part')end;lib.close()
local backup=open(src);local parts={};assert(backup.export(function(chunk)parts[#parts+1]=chunk end).ok);backup.close();local bytes=table.concat(parts)
local function stream(s)local at=1;return function()if at>#s then return nil end;local chunk=s:sub(at,at+1023);at=at+#chunk;return chunk end end
local function verify(p)
 local x=open(p);assert(not x.status().pending);local result={};x.export(function(c)result[#result+1]=c end);assert(table.concat(result)==bytes,'roundtrip');x.close()
 local e=F.new(p..'/editor',host);assert(not A.decode(e.read(A.name,A.max_bytes)).enabled);e.close()
end
local p=dirs('roundtrip');local x=open(p);assert(x.restore(string.rep('b',32),stream(bytes),#bytes).ok);x.close();verify(p)
print('PASS backup: names, draft, annual plan, controls, MP3 byte-for-byte roundtrip; auto disabled')
for _,point in ipairs({'validated','pending','disabled','media','draft','controls','verified','complete'})do
 p=dirs('fault-'..point);x=open(p,function(name)if name==point then error('injected interruption')end end)
 local result=x.restore(string.rep('c',32),stream(bytes),#bytes);x.close();assert(not result.ok)
 if point=='validated' then local e=F.new(p..'/editor',host);assert(S.load(e).revision=='empty');e.close()
 elseif point=='complete' then verify(p)
 else
  assert(not pcall(F.new,p..'/editor',host),'pending must block ordinary writers')
  x=open(p);assert(x.status().pending);assert(x.resume(string.rep('c',32)).ok);x.close();verify(p)
 end
 print('PASS restore interruption '..point)
end
local function rejected(label,content,size,zone)
 local q=dirs(label);local b=open(q,nil,zone);local out=b.restore(string.rep('d',32),stream(content),size or #content);assert(not out.ok and not b.status().pending);b.close()
 local f=F.new(q..'/editor',host);assert(S.load(f).revision=='empty' and not f.stat('sound-control.json')and not f.stat(A.name));f.close();print('PASS reject '..label)
end
rejected('truncated',bytes:sub(1,-20),#bytes);rejected('magic','X'..bytes:sub(2));rejected('tail',bytes..'junk');rejected('timezone',bytes,nil,'OTHER')
rejected('corrupt',bytes:sub(1,-2)..string.char((bytes:byte(-1)+1)%256))
-- Rebuild a valid header checksum around an invalid/path-escaping schema.
local Codec=require('schoolbell.backup_codec');local length=tonumber(bytes:sub(#Codec.magic+1,#Codec.magic+8));local start=#Codec.magic+9+65+1;local raw=bytes:sub(start,start+length-1);local payload=bytes:sub(start+length)
local manifest=C.decode(raw);manifest.files[4].name='../escaped.mp3';raw=C.encode(manifest)
rejected('traversal',Codec.magic..string.format('%08d\n',#raw)..C.sha(raw)..'\n'..raw..payload)
print('PASS backup negative cases and persistent resume barriers')

-- Replace an existing library, preserving the immutable original audio files.
local q=dirs('existing');local mf=F.new(q..'/media',host);local ml=L.open(mf,q..'/media',function()return true end)
mf.copy(sample,'upload.part',524288);assert(ml.replace('user8','old.mp3',0,string.rep('e',32),q..'/media/upload.part',require('schoolbell.mp3').inspect(sample),'Старая').status=='saved');mf.unlink('upload.part');ml.close()
local z=open(q);assert(z.restore(string.rep('f',32),stream(bytes),#bytes).ok);z.close();verify(q)
-- A user-enabled active snapshot cannot be replaced, and no stream is read.
local ed=F.new(q..'/editor',host);local raw=ed.read(A.name,A.max_bytes);local current=C.decode(raw).data;current.enabled=true;current.boot='synthetic';current.zone='UTC';current.plan=data;current.revision=C.sha(C.encode(data));ed.unlink(A.name);ed.write(A.name,C.encode({data=current,checksum=C.sha(C.encode(current))}));ed.close()
z=open(q);assert(not pcall(z.restore,string.rep('9',32),function()error('must not read')end,#bytes));z.close()
print('PASS existing library replacement and enabled-auto refusal')

-- Lua 5.1 HTTP sinks/sources yield; every protected frame along the path must cooperate.
local function copcall(fn,...)
 local co=coroutine.create(fn);local args={...}
 while true do
  local values={coroutine.resume(co,unpack(args))};if not values[1]then return false,values[2]end
  if coroutine.status(co)=='dead'then return unpack(values)end
  table.remove(values,1);args={coroutine.yield(unpack(values))}
 end
end
local streamed={};local co=coroutine.create(function()
 local b=open(src,nil,nil,copcall);assert(b.export(function(c)coroutine.yield(c)end).ok);b.close()
end)
while coroutine.status(co)~='dead'do local ok,c=coroutine.resume(co);assert(ok,c);if c then streamed[#streamed+1]=c end end
assert(table.concat(streamed)==bytes)
local target=dirs('yielding-upload');local response
co=coroutine.create(function()
 local b=open(target,nil,nil,copcall);local source=stream(bytes)
 response=b.restore(string.rep('8',32),function()coroutine.yield('read');return source()end,#bytes);b.close()
end)
while coroutine.status(co)~='dead'do local ok,why=coroutine.resume(co);assert(ok,why)end
assert(response.ok);verify(target)
print('PASS yielding HTTP download/upload under Lua 5.1 protected calls')
