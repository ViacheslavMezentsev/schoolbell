package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local C=require('schoolbell.media_codec');local A=require('schoolbell.automatic_store');local S=require('schoolbell.schedule_store')
local files={};local function sealed(v)return C.encode({data=v,checksum=C.sha(C.encode(v))})end
files[A.name]=sealed({enabled=false,generation=2,watermark=0})
local closed=true;local gate=false;local forks=0;local failed=false;local now=100
local storage={read=function(k)return files[k]end,write=function(k,v)assert(not files[k]);files[k]=v end,rename=function(a,b)files[b]=files[a];files[a]=nil end,stat=function(k)return files[k]and {}end,unlink=function(k)files[k]=nil end,sync=function()end,space=function()return 2000000,4000000 end,close=function()closed=true end}
package.loaded['schoolbell.media_fs']={new=function()closed=false;return storage end}
package.loaded['schoolbell.sound_test']={lock='gate'}
package.loaded['nixio.fs']={mkdir=function()if gate then return false end;gate=true;return true end,rmdir=function()assert(gate);gate=false;return true end,lstat=function()return nil end}
package.loaded.nixio={fork=function()assert(not A.decode(files[A.name]).enabled);forks=forks+1;if failed then return nil end;return 123 end,exec=function()error('must not execute on host')end}
local clock={disable=function()end,configure=function()assert(closed,'clock reopened under editor lock')end}
local function perform(target,broken)
 failed=broken;local handle,busy=require('schoolbell.system_actions').system(function()return now end)
 local id=string.rep('a',32);local owner=string.rep('b',64)
 assert(handle({action='system_prepare',target=target,id=id,owner=owner}).ok)
 local r=handle({action='system_'..target,challenge=id,id=id,owner=owner,ack='true'})
 assert(closed and not gate);return r,busy
end
local r,busy=perform('reboot',false);assert(r.ok and forks==1 and busy());now=116;assert(not busy())
r=perform('reboot',true);assert(not r.ok and forks==2)
r=perform('reset',false);assert(r.ok and S.load(storage).ok and forks==2)
print('PASS system ports: persist auto-off before fork, fork failure unlock, reboot guard, reset clock only after storage unlock; no real reboot')
