-- Explicit isolated target test; no live UCI writes, reload, clock or sound.
local M=require('schoolbell.timezone')
local fs=require('nixio.fs');local n=require('nixio')
local root='/tmp/schoolbell-timezone-regression-'..n.getpid()
assert(fs.mkdir(root,700));local backend
local function write(name,text)local f=assert(io.open(root..'/'..name,'wb'));assert(f:write(text));assert(f:close())end
local function read(name)local f=assert(io.open(root..'/'..name,'rb'));local s=f:read('*a');f:close();return s end
local ok,err=pcall(function()
 write('system',"config system\n option hostname 'fixture'\n option timezone 'UTC'\n")
 write('TZ','UTC\n')
 local options={config_dir=root,runtime_file=root..'/TZ',pending_file=root..'/pending',apply=function()return false end}
 backend=M.system(options);local before=M.request(backend);assert(before.ok)
 local result=M.request(backend,'Asia/Yekaterinburg',before.revision)
 assert(result.code=='apply_failed' and result.saved,'commit must precede apply')
 backend.close();backend=nil
 local raw=read('system');assert(raw:find("option zonename 'Asia/Yekaterinburg'",1,true),'zone missing on disk')
 assert(raw:find("option timezone '<+05>-5'",1,true),'offset missing on disk')
 backend=M.system(options);local after=M.request(backend)
 assert(after.ok and after.zone=='Asia/Yekaterinburg' and after.revision~=before.revision,'fresh staging read')
 assert(not after.runtime_ok,'fake apply must not claim active timezone')
 backend.close();backend=nil
 print('PASS target timezone: anonymous section; disk commit; fresh staging; failed apply reported honestly')
end)
if backend then pcall(backend.close)end
fs.unlink(root..'/system');fs.unlink(root..'/TZ');fs.rmdir(root)
assert(ok,err)
