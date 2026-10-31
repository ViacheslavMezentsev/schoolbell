local root,mode,target,source1,source2=unpack(arg)
local C=require('schoolbell.media_codec');local Fs=require('schoolbell.media_fs');local Manager=require('schoolbell.media_manager')
local host=os.getenv('MEDIA_HOST')=='1' and require('schoolbell.media_fs_host') or nil
local fs=Fs.new(root,host)
local function hash_file(path)local f=assert(io.popen('sha256sum '..path));local h=f:read('*l'):match('^([0-9a-f]+)');assert(f:close());return h end
local function data(source)
 local f=assert(io.open(source,'rb'));local size=assert(f:seek('end'));f:close();local h=hash_file(source)
 local duration,rate=3276,44100;if source:sub(-5)=='0.mp3' then duration,rate=10319,32000 end
 local docs={['catalog.json']=C.encode({melodies={{id='bell',name='Test',revisions={{revision=h,source='user',size_bytes=size,audio={format='mp3',duration_ms=duration,sample_rate_hz=rate,channels=2}}}}}}),['settings.json']='{}', ['schedules.json']=C.encode({references={{id='bell',revision=h}}}),['plans.json']='{"references":[]}'}
 return docs,{[h]=source},h
end
local ops={string.rep('1',32),string.rep('2',32),string.rep('3',32)}
local visits={};local m=Manager.new(fs,{ownership_safe=function()return true end,checkpoint=function(stage)
 visits[#visits+1]=stage
 if stage==target then if mode=='crash' then os.exit(77)else error('injected '..stage)end end
end})
if mode=='init' then
 local docs,imports=data(source1);local x=m.commit(ops[1],0,docs,imports,true);assert(x.status=='saved',x.error);assert(m.recover().state=='ready')
elseif mode=='run' or mode=='crash' or mode=='fault' then
 local docs,imports=data(source2);local x=m.commit(ops[2],1,docs,imports);if mode=='run'then assert(x.status=='saved',x.error)else assert(x.status~='saved' or target=='saved',x.error)end
 print('RESULT',x.status);print('POINTS',table.concat(visits,','))
elseif mode=='verify' then
 local state=m.recover();assert(state.state=='ready',state.error or state.state);assert(state.generation==1 or state.generation==2)
 local found=m.lookup(ops[state.generation]);assert(found.state=='retained');assert(m.lookup(string.rep('9',32)).state=='unknown')
 assert(m.cleanup().status=='cleaned');assert(m.recover().generation==state.generation)
 print('RECOVERED',state.generation)
elseif mode=='basic' then
 assert(C.sha('')=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
 assert(C.sha('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
 assert(C.decode(C.encode({s='a\0\n\\"'})).s=='a\0\n\\"')
 local docs,imports,h=data(source1);assert(m.commit(ops[1],0,docs,imports,true).status=='saved')
 assert(not pcall(Fs.new,root,host),'second owner')
 assert(m.commit(ops[2],0,docs,imports).status=='conflict')
 local bad={};for k,v in pairs(docs)do bad[k]=v end;bad['catalog.json']='{"melodies":[],"melodies":[]}'
 assert(m.commit(ops[2],1,bad,{}).status=='rejected')
 bad['catalog.json']=docs['catalog.json'];bad['plans.json']='{"references":[{"id":"absent","revision":"'..h..'"}]}'
 assert(m.commit(ops[2],1,bad,{}).status=='rejected')
 local space=fs.space;fs.space=function()return 1,10000000 end;assert(m.commit(ops[2],1,docs,{}).status=='rejected');fs.space=space
 local original=fs.sync;fs.sync=function()error('fsync failure')end
 assert(m.commit(ops[2],1,docs,{}).status=='rejected');fs.sync=original
 assert(m.cleanup().status=='cleaned')
 local release=m.hold(h);local docs2,imports2=data(source2)
 -- Cleanup removed the uncommitted operation directory; it is safe to use a new ID.
 assert(m.commit(ops[3],1,docs2,imports2).status=='saved')
 assert(m.commit(string.rep('4',32),2,docs2,{}).status=='saved')
 assert(m.cleanup().status=='cleaned');assert(fs.stat('objects/'..h));assert(not pcall(m.close));release();release();assert(m.cleanup().status=='cleaned');assert(not fs.stat('objects/'..h))
 -- Corrupt current: verified recovery copy supplies a paused fallback, never autoplay.
 fs.unlink('current.json');fs.write('current.json','broken');fs.sync('current.json');fs.sync('')
 assert(m.recover().state=='paused');assert(m.cleanup().status=='cleanup_failed')
 assert(m.commit(string.rep('4',32),2,docs2,{}).status=='rejected' or m.recover().state=='paused')
 fs.unlink('recovery.json');fs.write('recovery.json','broken');fs.sync('recovery.json');fs.sync('')
 assert(m.recover().state=='recovery_required')
 print('PASS basic: hash, JSON, lock, generation, references, space, sync, lease, fallback, corrupt pointers')
elseif mode=='negative' then
 local docs,imports,h=data(source1);assert(m.commit(ops[1],0,docs,imports,true).status=='saved')
 local bad={};for k,v in pairs(docs)do bad[k]=v end
 local cat=C.decode(docs['catalog.json']);cat.melodies[1].revisions[1].size_bytes=524289;bad['catalog.json']=C.encode(cat)
 assert(m.commit(ops[2],1,bad,imports).status=='rejected')
 cat=C.decode(docs['catalog.json']);local wrong=string.rep('0',64);cat.melodies[1].revisions[1].revision=wrong;bad['catalog.json']=C.encode(cat);bad['schedules.json']='{"references":[]}'
 assert(m.commit(ops[2],1,bad,{[wrong]=source1}).status=='rejected');assert(m.cleanup().status=='cleaned')
 local docs2,imports2,h2=data(source2);assert(m.commit(ops[2],1,docs2,imports2).status=='saved')
 fs.unlink('objects/'..h2);fs.write('objects/'..h2,'broken');fs.sync('objects/'..h2);fs.sync('objects')
 local state=m.recover();assert(state.state=='paused' and state.generation==1)
 assert(m.cleanup().status=='cleanup_failed');assert(m.lookup(ops[2]).state=='unknown')
 fs.unlink('objects/'..h2);fs.copy(source2,'objects/'..h2,524288);fs.sync('objects/'..h2);fs.sync('objects');assert(m.recover().state=='ready')
 local pointer=C.parse(fs.read('current.json',4096));pointer.generation=2147483647;assert(C.parse(C.seal(pointer)).generation==2147483647)
 pointer.generation=2147483648;assert(not pcall(C.seal,pointer))
 assert(m.commit(ops[3],2147483647,docs2,{}).status=='rejected')
 print('PASS negative: file size, import hash, corrupted object, fallback, lookup, generation bound')
elseif mode=='unsafe' then
 m.close();fs=Fs.new(root,host);m=Manager.new(fs);assert(m.recover().state=='recovery_required');print('PASS ownership gate')
else error('mode')end
m.close();local status=io.open('/proc/self/status','r');if status then local text=status:read('*a');status:close();print('RESOURCE',text:match('VmHWM:[^\n]+') or 'unavailable',string.format('lua_kib=%.1f cpu_s=%.3f',collectgarbage('count'),os.clock()))end;print('PASS',mode)
