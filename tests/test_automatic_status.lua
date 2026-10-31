local M=require('schoolbell.automatic_status');local Store=require('schoolbell.automatic_store');local C=require('schoolbell.media_codec')
local good={enabled=false,generation=1,watermark=0};local raw=C.encode({data=good,checksum=C.sha(C.encode(good))});assert(Store.decode(raw).generation==1)
local state={ok=true,state='disabled',enabled=false,generation=1,uptime=100,revision='kept'}
local blob=M.pack(raw,state,'boot')
-- GET path must not invoke full store decode, plan validation or SHA.
local decode=Store.decode;local sha=C.sha;Store.decode=function()error('full decode in GET')end;C.sha=function()error('hash in GET')end
assert(M.resolve(raw,blob,100,'boot').state=='disabled');assert(M.resolve(raw,blob,140,'boot').generation==1)
assert(M.resolve(raw,blob,141,'boot').state=='waiting');assert(M.resolve(raw,blob,99,'boot').state=='waiting')
assert(M.resolve(raw..' ',blob,100,'boot').state=='waiting')
local changed=raw:gsub('false','true');assert(#changed~=#raw or changed~=raw);assert(M.resolve(changed,blob,100,'boot').state=='waiting')
assert(M.resolve(raw,blob,100,'other').state=='unavailable');assert(M.resolve(raw,'broken',100,'boot').state=='unavailable')
assert(M.resolve(nil,blob,100,'boot').state=='waiting');assert(M.resolve('',M.pack(nil,state,'boot'),100,'boot').state=='waiting')
assert(M.resolve(nil,M.pack(nil,state,'boot'),100,'boot').state=='disabled')
assert(M.resolve(raw,string.rep('x',24577),100,'boot').state=='unavailable')
assert(M.resolve(raw,M.pack(raw,{ok=true,state='running',uptime=100},'boot'),100,'boot').state=='unavailable')
Store.decode=decode;C.sha=sha
-- Corruption still fails full admission and cannot match the old witness.
assert(not pcall(Store.decode,changed));assert(not pcall(Store.decode,raw..'garbage'))
print('PASS fast status: exact bytes, corruption, TTL boundaries, boot changes, missing/empty, invalid snapshot and no expensive validation in reads')

local originalopen=io.open;local files={};local fail,private=false,true;local closes=0
local root=M.root
package.loaded['nixio.fs']={lstat=function(path)
 if path==root then return {type='dir',uid=0,modedec=private and '700' or '755'}end
 if files[path]then return {type='reg',uid=0,size=#files[path]}end
end}
package.loaded['schoolbell.media_fs']={new=function()return {
 stat=function(p)return files[root..'/'..p]end,
 unlink=function(p)files[root..'/'..p]=nil end,
 write=function(p,v)if fail=='write'then error('write failed')end;files[root..'/'..p]=v end,
 rename=function(a,b)if fail=='rename'then error('rename failed')end;files[root..'/'..b]=files[root..'/'..a];files[root..'/'..a]=nil end,
 close=function()closes=closes+1 end}end}
io.open=function(path)
 local data=path=='/proc/uptime' and '100.00 0' or path=='/proc/sys/kernel/random/boot_id' and 'boot' or files[path]
 if not data then return nil end
 return {read=function(_,n)return data:sub(1,n)end,close=function()return true end}
end
M.invalidate();M.publish(raw,state,'boot');assert(M.read(raw).state=='disabled')
assert(M.read(changed).state=='waiting')
for _,fault in ipairs({'write','rename'})do
 fail=fault;local before=closes;assert(not pcall(M.publish,changed,state,'boot'));assert(closes==before+1,'lock leaked')
 assert(M.read(changed).state=='waiting','partial publication admitted')
 M.invalidate();assert(M.read(raw).state=='unavailable');fail=false;M.publish(raw,state,'boot')
end
private=false;assert(M.read(raw).state=='unavailable');assert(not pcall(M.publish,raw,state,'boot'));private=true
M.invalidate();assert(M.read(raw).state=='unavailable')
io.open=originalopen
print('PASS fast status filesystem: atomic rename, write/rename faults, invalidation, private root and lock release')
