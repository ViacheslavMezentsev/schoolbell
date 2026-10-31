-- Isolated schoolbell-clock/1 codec. No filesystem, clock or runtime integration.
local J=require('modbus.json_strict')
local SHA=require('schoolbell.media_codec').sha
local M={max_bytes=1024,max_integer=9007199254740991}
local function fields(v,names)
 assert(type(v)=='table' and v~=J.null and J.kind(v)~='array','object')
 local allowed={};for _,k in ipairs(names)do allowed[k]=true;assert(v[k]~=nil,'missing field')end
 for k in pairs(v)do assert(allowed[k],'unknown field')end
end
function M.integer(v)return type(v)=='number' and v>=0 and v<=M.max_integer and v==math.floor(v)end
function M.data(v)
 fields(v,{'format','source','confirmed_utc_ms','checkpoint_utc_ms'})
 assert(v.format=='schoolbell-clock/1' and v.source=='manual','format/source')
 assert(M.integer(v.confirmed_utc_ms) and M.integer(v.checkpoint_utc_ms) and v.checkpoint_utc_ms>=v.confirmed_utc_ms,'timestamps')
 return string.format('{"checkpoint_utc_ms":%.0f,"confirmed_utc_ms":%.0f,"format":"schoolbell-clock/1","source":"manual"}',v.checkpoint_utc_ms,v.confirmed_utc_ms)
end
function M.encode(v)
 local data=M.data(v);local hash=SHA(data)
 local raw='{"checksum":"'..hash..'","data":'..data..'}';assert(#raw<=M.max_bytes)
 return raw,hash
end
function M.decode(raw)
 assert(type(raw)=='string' and #raw<=M.max_bytes,'size')
 local v=assert(J.decode(raw,{bytes=1024,depth=3,nodes=16,string_bytes=128}))
 fields(v,{'data','checksum'});local data=M.data(v.data)
 for _,k in ipairs({'confirmed_utc_ms','checkpoint_utc_ms'})do assert(J.number_kind(v.data,k)=='integer','integer syntax')end
 assert(type(v.checksum)=='string' and #v.checksum==64 and not v.checksum:find('[^0-9a-f]') and v.checksum==SHA(data),'checksum')
 return v.data,v.checksum
end
return M
