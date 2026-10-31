package.path='./src/lua/?.lua;./vendor/?.lua;'..package.path
local C=require('schoolbell.media_codec');local J=require('modbus.json_strict')
local codec=dofile('src/portable-plan/codec.lua')
local dir=assert(arg[1]);local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local cases=assert(J.decode(read(dir..'/index.json')))
local serial=0
local function factory()
 serial=serial+1;local path=dir..'/hash-'..serial
 local f=assert(io.open(path,'wb'));return {
 update=function(_,c)return f:write(c)~=nil end,
 finish=function()f:close();local p=assert(io.popen("sha256sum '"..path:gsub("'","'\\''").."'"));local s=p:read('*l');p:close();os.remove(path);return assert(s):sub(1,64)end}
end
local function source(path,n)
 local f=assert(io.open(path,'rb'));local ended=false
 return function()if ended then return nil end;local c=f:read(n);if not c then f:close();ended=true end;return c end,f
end
local count=0
for _,v in ipairs(cases)do
 for _,n in ipairs(v.chunks)do
  local src,f=source(dir..'/'..v.file,n);local chunks={}
  local ok,result=pcall(codec.decode,src,factory,function(name,c)chunks[name]=(chunks[name] or '')..c end)
  pcall(function()f:close()end)
  assert(ok==v.ok,v.name..'/'..n..' unexpected: '..tostring(result))
  if ok then
   assert(result.admitted==false and result.bytes==v.size)
   local encoded={}
   codec.encode(read(dir..'/'..v.file..'.manifest'),function(name)local s=assert(chunks[name]);local i=1;return function()if i>#s then return nil end;local c=s:sub(i,i+n-1);i=i+#c;return c end end,factory,function(c)assert(#c<=16384);encoded[#encoded+1]=c end)
   assert(table.concat(encoded)==read(dir..'/'..v.file),'roundtrip '..v.name)
  end
  count=count+1
 end
end
local valid=dir..'/golden.sbp'
local function rejects(fn)local ok=pcall(fn);assert(not ok)end
rejects(function()codec.decode(function()return ''end,factory)end)
rejects(function()codec.decode(function()return string.rep('x',16385)end,factory)end)
rejects(function()codec.decode(function()return nil,'read failed'end,factory)end)
local src,f=source(valid,7);rejects(function()codec.decode(src,factory,function()return false end)end);f:close()
local src2,f2=source(valid,7);rejects(function()codec.decode(src2,function()return{update=function()return false end}end)end);f2:close()
local raw=read(valid..'.manifest')
rejects(function()codec.encode(raw,function()return function()return nil end end,factory,function()return true end)end)
rejects(function()codec.encode(raw,function()error('must not open')end,factory,function()return false end)end)
print('[sbp Lua] '..count..' shared stream cases + callback failures passed')
