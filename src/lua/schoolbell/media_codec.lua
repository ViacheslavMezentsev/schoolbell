-- Private storage codec; SHA-256 of small metadata, no audio execution.
local J=require('modbus.json_strict')
local M={null=J.null}
local function bx(a,b,op)
 local v,p=0,1
 for _=1,32 do local x,y=a%2,b%2
  if (op=='xor' and x~=y) or (op=='and' and x==1 and y==1) then v=v+p end
  a=math.floor(a/2);b=math.floor(b/2);p=p*2
 end
 return v
end
local function xor(a,b,c)local v=bx(a,b,'xor');return c and bx(v,c,'xor') or v end
local function band(a,b)return bx(a,b,'and')end
local loaded,n=pcall(require,'nixio');if not loaded then loaded,n=pcall(require,'schoolbell.media_fs_host');n=loaded and {bit=n} or nil end
if loaded and n.bit then
 local b=n.bit
 xor=function(a,z,c)local v=b.bxor(a,z)%2^32;return c and b.bxor(v,c)%2^32 or v end
 band=function(a,z)return b.band(a,z)%2^32 end
end
local function rr(x,n)return math.floor(x/2^n)+(x%2^n)*2^(32-n)end
local K={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
-- Exact byte keys only: never cache a file/path or skip reading changed data.
-- At most four metadata strings (64 KiB total) plus four digest strings.
local hashes,next_hash={},1
local observer,observing
function M.set_observer(fn)
 assert(fn==nil or type(fn)=='function','observer')
 observer=fn
end
local function pulse()
 if not observer or observing then return end
 observing=true;local ok,err=pcall(observer);observing=false
 if not ok then error(err)end
end
function M.sha(s)
 assert(type(s)=='string' and #s<=16384,'metadata hash bound')
 pulse()
 for _,v in ipairs(hashes)do if v.bytes==s then return v.digest end end
 local bytes=s
 local n=#s*8;s=s..'\128'..string.rep('\0',(55-#s)%64)..'\0\0\0\0'..string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256)
 local H={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
 for off=1,#s,64 do
  if (off-1)%256==0 then pulse()end
  local w={};for i=0,15 do local a,b,c,d=s:byte(off+i*4,off+i*4+3);w[i]=((a*256+b)*256+c)*256+d end
  for i=16,63 do local x,y=w[i-15],w[i-2];w[i]=(w[i-16]+xor(rr(x,7),rr(x,18),math.floor(x/8))+w[i-7]+xor(rr(y,17),rr(y,19),math.floor(y/1024)))%2^32 end
  local a,b,c,d,e,f,g,h=unpack(H)
  for i=0,63 do
   local t=(h+xor(rr(e,6),rr(e,11),rr(e,25))+xor(band(e,f),band(4294967295-e,g))+K[i+1]+w[i])%2^32
   local u=(xor(rr(a,2),rr(a,13),rr(a,22))+xor(band(a,b),band(a,c),band(b,c)))%2^32
   h=g;g=f;f=e;e=(d+t)%2^32;d=c;c=b;b=a;a=(t+u)%2^32
  end
  local z={a,b,c,d,e,f,g,h};for i=1,8 do H[i]=(H[i]+z[i])%2^32 end
 end
 local out={};local digits='0123456789abcdef';for i=1,8 do local x=H[i];local hex='';for _=1,8 do local k=x%16;hex=digits:sub(k+1,k+1)..hex;x=math.floor(x/16)end;out[i]=hex end;local digest=table.concat(out)
 hashes[next_hash]={bytes=bytes,digest=digest};next_hash=next_hash%4+1
 return digest
end
function M.encode(v)
 if v==J.null then return 'null' end
 if type(v)=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"' end
 if type(v)=='number' then assert(v==math.floor(v) and math.abs(v)<=2147483647);return string.format('%.0f',v)end
 if type(v)=='boolean' then return tostring(v)end
 assert(type(v)=='table');local a={}
 if J.kind(v)=='array' or (#v>0) then for i=1,#v do a[i]=M.encode(v[i])end;return '['..table.concat(a,',')..']'end
 local keys={};for k in pairs(v)do assert(type(k)=='string');keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do a[#a+1]=M.encode(k)..':'..M.encode(v[k])end;return '{'..table.concat(a,',')..'}'
end
function M.decode(s)local v,e=J.decode(s);assert(v,e and e.code);return v end
function M.fields(t,keys)
 assert(type(t)=='table' and t~=J.null,'object');local allowed={}
 for _,k in ipairs(keys)do allowed[k]=true;assert(t[k]~=nil,'missing '..k)end
 for k in pairs(t)do assert(allowed[k],'unknown field')end
end
function M.hex(s,n)return type(s)=='string' and #s==n and s:match('^[0-9a-f]+$')~=nil end
function M.integer(x,lo,hi)return type(x)=='number' and x==math.floor(x) and x>=lo and x<=hi end
function M.pointer(p)
 M.fields(p,{'generation','current','previous','checksum'});assert(M.integer(p.generation,1,2147483647),'generation')
 local function ref(x)M.fields(x,{'snapshot','sha256'});assert(M.hex(x.snapshot,32) and M.hex(x.sha256,64),'reference')end
 ref(p.current);if p.previous~=J.null then ref(p.previous)end
 local prev=p.previous
 return table.concat({'schoolbell-pointer',string.format('%.0f',p.generation),p.current.snapshot,p.current.sha256,prev==J.null and '-' or prev.snapshot,prev==J.null and '-' or prev.sha256,''},'\n')
end
function M.seal(p)p.checksum='';p.checksum=M.sha(M.pointer(p));return M.encode(p)end
function M.parse(s)local p=M.decode(s);assert(M.hex(p.checksum,64) and p.checksum==M.sha(M.pointer(p)),'pointer checksum');return p end
return M
