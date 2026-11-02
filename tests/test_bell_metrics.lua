package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local M=require('schoolbell.bell_metrics')
local C=require('schoolbell.media_codec')
local function fixture(seed,fail)
 local files={};for k,v in pairs(seed or {})do files[k]=v end
 local step=0;local function op()step=step+1;if step==fail then error('injected')end end
 local fs={read=function(p,max)local s=files[p];assert(not s or #s<=max);return s end,stat=function(p)return files[p]end,space=function()return 1048576 end}
 function fs.write(p,v)op();assert(not files[p]);files[p]=v end
 function fs.sync()op()end
 function fs.rename(a,z)op();files[z]=assert(files[a]);files[a]=nil end
 function fs.unlink(p)op();files[p]=nil end
 return fs,files
end
local function date(t)return '2026-11-'..string.format('%02d',t)end
local rows={{seq=1,time=1,action='auto_enabled'},{seq=2,time=1,action='auto_ok'},{seq=3,time=1,action='play_ok'},{seq=4,time=1,action='auto_skipped'},{seq=5,time=1,action='auto_ok'},{seq=6,time=2,action='auto_ok'}}
local fs,files=fixture();M.sync(fs,rows,date);local v=M.load(fs);assert(#v.days==2 and v.days[1].count==2 and v.days[2].count==1 and v.cursor==6)
local before=files['bell-metrics.json'];M.sync(fs,rows,date);assert(files['bell-metrics.json']==before)
local reboot=fixture(files);M.sync(reboot,rows,date);assert(M.load(reboot).days[1].count==2)
-- A retained journal tail is enough after rotation; date rollback updates the old day.
rows={{seq=7,time=1,action='auto_ok'}};M.sync(fs,rows,date);assert(M.load(fs).days[1].count==3)
local original=files['bell-metrics.json'];rows={{seq=8,time=2,action='auto_ok'}}
for fail=1,4 do
 local f,storage=fixture({['bell-metrics.json']=original},fail);pcall(M.sync,f,rows,date)
 local recovered=fixture(storage);M.sync(recovered,rows,date);local r=M.load(recovered);assert(r.days[2].count==2,'replay must count once')
end
local corrupt=fixture({['bell-metrics.json']='broken'});assert(not pcall(M.sync,corrupt,rows,date))
local low=fixture({['bell-metrics.json']=original});low.space=function()return 0 end;assert(not pcall(M.sync,low,rows,date));assert(low.read('bell-metrics.json',32768)==original)
assert(not pcall(M.project,M.load(fs),{{seq=1,time=1,action='auto_ok'}},date))
local f=fixture();local many={};for i=1,401 do many[i]={seq=i,time=i,action='auto_ok'}end
local function fakeDate(i)return string.format('%04d-01-01',2000+i)end
M.sync(f,many,fakeDate);local bounded=M.load(f);assert(#bounded.days==400 and bounded.days[1].date=='2002-01-01')
local pure=fixture();local projected,pending=M.project(M.load(pure),{{seq=1,time=1,action='auto_ok'}},date);assert(pending and projected.days[1].count==1 and pure.read('bell-metrics.json',32768)==nil)
print('PASS bell metrics: auto-only, dedup/restart/rotation, rollback dates, atomic failure recovery, corrupt/full storage, bounded history and read-only projection')

local Journal=require('schoolbell.journal');local durable=fixture()
for i=1,650 do Journal.append(durable,i%2==0 and 'auto_ok' or 'play_ok',1)end
M.sync(durable,(Journal.read(durable)))
local history=M.load(durable);assert(#history.days==1 and history.days[1].count==325)
M.sync(durable,(Journal.read(durable)));assert(M.load(durable).days[1].count==325)
print('PASS bell metrics integration: 650 journal events, rotation preserves all 325 automatic completions without browser')

local requestfs,requestfiles=fixture(files);requestfs.close=function()end
requestfiles['journal-current.jsonl']=C.encode({seq=8,time=2,action='auto_ok'})..'\n'
package.loaded['schoolbell.media_fs']={new=function()return requestfs end}
local savedRead=Journal.read;Journal.read=function()return {{seq=8,time=2,action='auto_ok'}},8 end
local beforeRequest=requestfs.read('bell-metrics.json',32768)
local response=M.request('/unused',requestfs);assert(response.ok and response.persistence_pending)
assert(requestfs.read('bell-metrics.json',32768)==beforeRequest)
Journal.read=savedRead
print('PASS metrics GET: pending events visible, no file writes')

Journal.read=function()return {{seq=8,time=2,action='auto_ok'}},8 end
assert(M.reconcile('/unused'));assert(not M.request('/unused',requestfs).persistence_pending)
local stable=requestfs.read('bell-metrics.json',32768);assert(M.reconcile('/unused'));assert(requestfs.read('bell-metrics.json',32768)==stable)
Journal.read=savedRead
print('PASS metrics startup: disabled-mode reconciliation and idempotent retry')

local tmp=os.tmpname();os.remove(tmp);assert(os.execute('mkdir -m 700 '..tmp)==0)
for _,name in ipairs({'bell-metrics.json','journal-current.jsonl'})do local f=assert(io.open(tmp..'/'..name,'wb'));assert(f:write(requestfiles[name]));assert(f:close())end
package.loaded['nixio.fs']={lstat=function(path)
 if path==tmp then return {type='dir',modedec='700'}end
 local f=io.open(path,'rb');if not f then return nil end;local size=f:seek('end');f:close();return {type='reg',size=size}
end}
package.loaded['schoolbell.media_fs']={new=function()error('GET must not acquire editor lock')end}
local unlocked=M.request(tmp);assert(unlocked.ok and not unlocked.persistence_pending)
for _,name in ipairs({'bell-metrics.json','journal-current.jsonl'})do assert(os.remove(tmp..'/'..name))end
assert(os.remove(tmp))
print('PASS metrics GET: real bounded files read without editor lock')

for _,raw in ipairs({'{"version":1,"cursor":0,"days":{}}','{"version":1,"cursor":1,"days":[{"date":"2026-02-30","count":1}]}','{"version":1,"cursor":1,"days":[{"date":"2026-11-02","count":-1}]}'})do local invalid=fixture({['bell-metrics.json']=raw});assert(not pcall(M.load,invalid))end
print('PASS metrics schema: object-as-array, invalid calendar date and negative count rejected')

local maximum={version=1,cursor=2147483647,days={}}
for i=1,400 do maximum.days[i]={date=string.format('%04d-01-01',2000+i),count=999999999}end
local maximumRaw=C.encode(maximum);assert(#maximumRaw<=M.max_bytes)
local maximumFs=fixture({['bell-metrics.json']=maximumRaw});assert(#M.load(maximumFs).days==400)
print('PASS metrics worst-case encoded checkpoint fits the decoder bound')
