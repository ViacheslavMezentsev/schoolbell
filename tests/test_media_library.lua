local L=require('schoolbell.media_library');local F=require('schoolbell.media_fs');local C=require('schoolbell.media_codec')
local root=assert(arg[1]);local host=os.getenv('MEDIA_HOST') and require('schoolbell.media_fs_host') or nil
local fs=F.new(root,host);local lib=L.open(fs,root,function()return true end)
local initial=lib.list();assert(initial.generation==0 and #initial.slots==6);assert(initial.storage.total_kib>0 and initial.storage.free_kib>=0 and initial.storage.media_kib==0 and initial.storage.media_limit_kib==nil)
assert(lib.resolve('test')=='/usr/share/schoolbell-sound-test/test.mp3')
local function upload(source,id,op,gen)
 if fs.stat('upload.part')then fs.unlink('upload.part')end
 fs.copy(source,'upload.part',524288)
 return lib.replace(id,'Звонок.mp3',gen,op,root..'/upload.part',require('schoolbell.mp3').inspect(source))
end
local cwd=assert(os.getenv('PWD'));local source=cwd..'/assets/melodies/test.mp3';local second=cwd..'/assets/melodies/0.mp3'
local a=upload(source,'user1',string.rep('a',32),0);assert(a.status=='saved')
local path,meta=lib.resolve('user1');assert(path==root..'/objects/'..a.revision and meta.source=='user')
assert(lib.resolve('0')=='/usr/share/schoolbell-sound-test/0.mp3');assert(not pcall(upload,source,'0',string.rep('f',32),1),'protected bundled slot');local before=fs.read('current.json',4096)
local b=upload(second,'user1',string.rep('b',32),0);assert(b.status=='conflict' and fs.read('current.json',4096)==before)
b=upload(second,'user1',string.rep('b',32),1);assert(b.status=='saved' and b.revision~=a.revision)
assert(fs.stat('objects/'..a.revision),'previous revision retained');assert(lib.list().storage.media_kib==math.ceil((13104+2*41273)/1024))
local c=upload(second,'user2',string.rep('c',32),2);assert(c.status=='saved');assert(not fs.stat('objects/'..a.revision),'unreferenced old revision collected')
local real_space=fs.space;fs.space=function()return 0,4000000 end
assert(not pcall(upload,source,'user1',string.rep('d',32),3));fs.space=real_space
assert(not pcall(upload,source,'../test',string.rep('e',32),3))
fs.unlink('upload.part');lib.close()
fs=F.new(root,host);lib=L.open(fs,root,function()return true end);assert(lib.list().generation==3)
for i=9,18 do local result=upload(source,'user'..i,string.format('%032x',i),i-6);assert(result.status=='saved')end
assert(#lib.list().slots==18);local p=lib.resolve('user18');assert(p and p:find('/objects/'));assert(lib.resolve('user1'));assert(lib.resolve('user2'))
-- Corruption pauses the whole library instead of silently switching to bundled audio.
fs.write('broken','{}');fs.rename('broken','current.json');assert(not pcall(lib.resolve,'0'));lib.close()
print('PASS media library: native persistence, replace/CAS, previous/GC, quota, traversal, reopen, corruption')
