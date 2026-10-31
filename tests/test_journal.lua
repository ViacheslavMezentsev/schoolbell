local M=require('schoolbell.journal')
local function fixture(original,fail)
 local files={};for k,v in pairs(original or {})do files[k]=v end
 local n=0;local function step()n=n+1;if n==fail then error('injected failure')end end
 local fs={}
 function fs.read(p,max)local s=files[p];assert(not s or #s<=max);return s end
 function fs.stat(p)return files[p] and {size=#files[p]}end
 function fs.write(p,v)step();assert(not files[p]);files[p]=v end
 function fs.sync()step()end
 function fs.rename(a,b)step();assert(files[a]);files[b]=files[a];files[a]=nil end
 function fs.unlink(p)step();files[p]=nil end
 function fs.space()return 1024*1024 end
 return fs,files
end
local fs,files=fixture()
for i=1,800 do M.append(fs,'save_ok',1700000000+i) end
local rows,last=M.read(fs);assert(last==800 and #rows>1 and #rows<800)
for _,p in ipairs({'journal-current.jsonl','journal-previous.jsonl'})do assert(files[p] and #files[p]<=16384)end
assert(not files['journal-next.tmp'])
M.append(fs,'storage_error',1600000000);rows,last=M.read(fs);assert(last==801 and rows[#rows].source=='system')
print('PASS journal: bounded rotation, sequential order despite clock rollback, source classes')
local before=files['journal-current.jsonl'];assert(not pcall(M.append,fs,string.rep('x',500),1700000000));assert(files['journal-current.jsonl']==before)
local bad,badfiles=fixture({['journal-current.jsonl']=string.rep('x',16385)});assert(not pcall(M.append,bad,'save_ok',1700000000));assert(#badfiles['journal-current.jsonl']==16385)
print('PASS journal: invalid/oversized input rejected without replacing evidence')
-- Build a nearly full current segment so the next append rotates.
local seed,base=fixture()
while true do
 local current=base['journal-current.jsonl'] or ''
 if #current>16262 then break end
 M.append(seed,'save_ok',1700000000)
end
for crash=1,6 do
 local f,storage=fixture(base,crash);pcall(M.append,f,'installed',1700000001)
 local recovered=fixture(storage);
 local oldrows,oldlast=M.read(recovered);assert(#oldrows>0)
 M.append(recovered,'save_ok',1700000002);local after,seq=M.read(recovered);assert(seq==oldlast+1 and #after>0)
end
print('PASS journal: recovery after every rotation write/sync/rename interruption')
local low,lowfiles=fixture();low.space=function()return 65536 end
assert(not pcall(M.append,low,'save_ok',1700000000));assert(not lowfiles['journal-current.jsonl'])
print('PASS journal: free-space reserve, no forced writes')

-- Retention boundary, future timestamps after rollback and sequence preservation.
local epoch=1800000000
local f,storage=fixture()
M.append(f,'save_ok',epoch-M.retention_seconds-1)
M.append(f,'save_ok',epoch-M.retention_seconds)
storage['journal-current.jsonl']=storage['journal-current.jsonl']..require('schoolbell.media_codec').encode({seq=3,time=epoch+100,source='user',level='info',action='save_ok'})..'\n'
local visible=M.read(f,epoch);assert(#visible==2 and visible[1].seq==2)
M.append(f,'installed',epoch)
local all,seq=M.read(f);assert(#all==3 and all[1].seq==2 and seq==4)
assert(all[2].time==epoch+100,'rollback must preserve future evidence')
M.append(f,'save_ok',epoch+M.retention_seconds+101)
all,seq=M.read(f);assert(#all==1 and seq==5,'expired history pruned, sequence retained')
print('PASS journal: seven-day boundary, future evidence, monotonic sequence after pruning all old rows')
-- Interrupted pruning of both segments leaves valid bounded evidence; retry recovers.
local old,oldfiles=fixture()
for i=1,360 do M.append(old,'save_ok',epoch-M.retention_seconds-100)end
assert(oldfiles['journal-previous.jsonl'])
for fail=1,16 do
 local io,files=fixture(oldfiles,fail);pcall(M.append,io,'installed',epoch)
 local nextio=fixture(files);local _,before=M.read(nextio)
 M.append(nextio,'save_ok',epoch+1);local kept,after=M.read(nextio)
 assert(after==before+1 and #kept>=1)
 for _,row in ipairs(kept)do assert(row.time>=epoch-M.retention_seconds)end
 for _,name in ipairs({'journal-current.jsonl','journal-previous.jsonl'})do assert(#(files[name] or '')<=16384)end
end
print('PASS journal: prune write/sync/rename failure recovery and segment bounds')

local localfs=fixture();M.append(localfs,'installed',epoch);localfs.close=function()return true end
local original_fs=package.loaded['schoolbell.media_fs'];local original_time=os.time
package.loaded['schoolbell.media_fs']={new=function()return localfs end};os.time=function()return epoch end
local response=M.request('/synthetic');os.time=original_time;package.loaded['schoolbell.media_fs']=original_fs
assert(response.ok and response.retention_seconds==604800 and response.limit_bytes==32768 and response.peak_bytes==49152)
assert(response.entries[1].local_time==os.date('%d.%m.%Y %H:%M:%S %z',epoch))
assert(response.entries[1].time==epoch,'stored UTC epoch unchanged')
print('PASS journal: response has device-local time and offset without altering stored UTC')
