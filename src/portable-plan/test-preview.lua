package.path='./src/lua/?.lua;./vendor/?.lua;'..package.path
local C=require('schoolbell.media_codec');local J=require('modbus.json_strict')
local P=dofile('src/portable-plan/preview.lua')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local dir=assert(arg[1]);local index=assert(J.decode(read(dir..'/index.json')))
for _,name in ipairs(index)do
 local ctx=assert(J.decode(read(dir..'/'..name..'.context')));local before=C.encode(ctx)
 local result=P.preview(read(dir..'/'..name..'.manifest'),read(dir..'/'..name..'.calendar'),ctx)
 assert(C.encode(ctx)==before,'mutated input '..name)
 assert(result.admitted==false and (result.ok or result.candidate==nil))
 print(C.encode({name=name,result=result}))
end
