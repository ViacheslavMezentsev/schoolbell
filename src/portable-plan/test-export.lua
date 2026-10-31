package.path='./src/lua/?.lua;./vendor/?.lua;'..package.path
local C=require('schoolbell.media_codec');local J=require('modbus.json_strict')
local E=dofile('src/portable-plan/export.lua');local D=dofile('src/portable-plan/codec.lua');local P=dofile('src/portable-plan/preview.lua')
local dir=assert(arg[1]);local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function array()return assert(J.decode('[]'))end
local serial=0
local function factory()
 serial=serial+1;local path=dir..'/hash-'..serial;local f=assert(io.open(path,'wb'))
 return {update=function(_,c)return f:write(c)~=nil end,finish=function()f:close();local p=assert(io.popen("sha256sum '"..path:gsub("'","'\\''").."'"));local s=p:read('*l');p:close();os.remove(path);return assert(s):sub(1,64)end}
end
for _,v in ipairs(assert(J.decode(read(dir..'/index.json'))))do
 local input=assert(J.decode(read(dir..'/'..v.name..'.json')));local before=C.encode(input);local output,opened={},array();local emitted=0
 local ok,why=pcall(function()
  local bytes=E.encode(input,function(slot,meta)
   opened[#opened+1]=slot;if v.fault=='open'then error('open')end
   local data=read(dir..'/'..v.name..'.'..slot);local i=1
   return function()if v.fault=='read'then error('read')end;if i>#data then return nil end;local c=data:sub(i,i+16383);i=i+#c;return c end
  end,factory,function(c)emitted=emitted+1;if v.fault=='emit'then return false end;assert(#c<=16384);output[#output+1]=c end)
  local archive=table.concat(output);assert(bytes==#archive);local f=assert(io.open(dir..'/'..v.name..'.lua.sbp','wb'));f:write(archive);f:close()
  local i=1;local parsed=D.decode(function()if i>#archive then return nil end;local c=archive:sub(i,i+16383);i=i+#c;return c end,factory)
  local inventory=array();for _,m in ipairs(input.media)do if not m.id:match('^user')then inventory[#inventory+1]={id=m.id,size_bytes=m.size_bytes,sha256=m.sha256}end end
  local ctx={draft={schedules=array(),plans=array(),pre_minutes=2,pre_media='test'},timezone=input.timezone,media=inventory,operation_id='0123456789abcdef0123456789abcdef',automatic_enabled=false,dirty=false,target='device',names={plans={},schedules={}}}
  local preview=P.preview(archive:sub(83,82+tonumber(archive:sub(9,16))),parsed.calendar,ctx);assert(preview.ok,C.encode(preview))
 end)
 assert(C.encode(input)==before,'mutated input');assert(ok==v.ok,v.name..': '..tostring(why));if v.early then assert(emitted==0,v.name..' emitted before validation')end
 print(C.encode({name=v.name,ok=ok,opened=opened}))
end
