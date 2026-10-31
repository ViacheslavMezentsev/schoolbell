-- Bounded MPEG Layer III frame scan; decoder validation is a separate step.
local M={}
function M.inspect(path)
 local f=assert(io.open(path,'rb'));local ok,result=pcall(function()
  local size=assert(f:seek('end'));assert(size>0 and size<=524288,'size');f:seek('set',0)
  local pos=0;local first=f:read(10)
  if first and first:sub(1,3)=='ID3' then
   assert(#first==10 and first:byte(4)>=2 and first:byte(4)<=4,'id3')
   local n=0;for i=7,10 do local b=first:byte(i);assert(b<128,'id3 size');n=n*128+b end
   pos=10+n;if first:byte(4)==4 and math.floor(first:byte(6)/16)%2==1 then pos=pos+10 end
   assert(pos<size,'id3 exceeds file')
  end
  local frames,samples,rate,channels=0,0
  while pos<size do
   f:seek('set',pos);local h=f:read(4);assert(h and #h==4,'truncated header')
   if size-pos==128 and h:sub(1,3)=='TAG' then pos=size;break end
   local a,b,c,d=h:byte(1,4);assert(a==255 and b>=224,'sync')
   local version=math.floor(b/8)%4;assert(version~=1 and math.floor(b/2)%4==1,'layer III')
   local bi=math.floor(c/16);local ri=math.floor(c/4)%4;assert(bi>0 and bi<15 and ri<3,'rate')
   local rates={44100,48000,32000};local sr=rates[ri+1]/(version==3 and 1 or version==2 and 2 or 4)
   local br=(version==3 and {32,40,48,56,64,80,96,112,128,160,192,224,256,320} or {8,16,24,32,40,48,56,64,80,96,112,128,144,160})[bi]
   local ch=math.floor(d/64)==3 and 1 or 2
   assert(not rate or (rate==sr and channels==ch),'changing stream format');rate=sr;channels=ch
   local len=math.floor((version==3 and 144000 or 72000)*br/sr)+math.floor(c/2)%2
   assert(len>=4 and pos+len<=size,'truncated frame');pos=pos+len;frames=frames+1;samples=samples+(version==3 and 1152 or 576)
   assert(samples/sr<=60,'duration')
  end
  assert(frames>=2 and rate,'no audio frames')
  return {format='mp3',duration_ms=math.ceil(samples*1000/rate),sample_rate_hz=rate,channels=channels},size
 end)
 f:close();assert(ok,result);return result
end
return M
