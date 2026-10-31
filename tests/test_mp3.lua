local M=require('schoolbell.mp3')
for _,id in ipairs({'test','0','1','2','3','4'})do local a=M.inspect('assets/melodies/'..id..'.mp3');assert(a.duration_ms>1000 and a.duration_ms<60000);print('PASS MP3 original '..id..' '..a.duration_ms)end
local function reject(data)
 local p=os.tmpname();local f=assert(io.open(p,'wb'));f:write(data);f:close();local ok=pcall(M.inspect,p);os.remove(p);assert(not ok)
end
reject('');reject('not mp3');reject('ID3'..string.rep('x',10));reject(string.rep('x',524289))
local f=assert(io.open('assets/melodies/test.mp3','rb'));local data=f:read('*a');f:close();reject(data:sub(1,#data-200));reject(data..'junk')
print('PASS MP3 empty, oversized, malformed, truncated and trailing junk')
