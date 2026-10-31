local S=require("schoolbell.schedule_store")
local C=require("schoolbell.media_codec")
local FS=require("schoolbell.media_fs")
local backend=os.getenv("MEDIA_HOST")=="1" and require("schoolbell.media_fs_host") or nil
local root,op,value,expected,stop=arg[1],arg[2],arg[3],arg[4],tonumber(arg[5])
local f=FS.new(root,backend)
local step=0
for _,name in ipairs({"write","sync","rename","unlink"}) do
 local original=f[name]
 f[name]=function(...)local out=original(...);step=step+1;if step==stop then os.exit(77)end;return out end
end
local result
if op=="save" then local input=assert(io.open(value,"rb"));local text=input:read("*a");input:close();result=S.save(f,text,expected)
else result=S.load(f) end
f.close()
print(C.encode(result))
