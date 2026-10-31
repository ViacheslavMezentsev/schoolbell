local P=require('schoolbell.clock_policy');local C=require('schoolbell.media_codec')
local function run(fail_at)
 local files={['clock-policy.json']=C.encode({enforced=true})};local count=0;local closed=false
 local function step()count=count+1;if count==fail_at then error('injected storage fault')end end
 local fs={stat=function(k)return files[k]~=nil end,read=function(k)step();return files[k]end,write=function(k,v)step();files[k]=v end,sync=function()step()end,rename=function(a,b)step();files[b]=files[a];files[a]=nil end,unlink=function(k)step();files[k]=nil end,close=function()closed=true end}
 package.loaded['schoolbell.media_fs']={new=function()return fs end}
 local ok=P.save('/private',false);assert(closed)
 if fail_at then assert(not ok);assert(files['clock-policy.pending'],'failed policy must retain interruption marker')
 else assert(ok and not files['clock-policy.pending'] and C.decode(files['clock-policy.json']).enforced==false)end
 return count
end
local count=run();for n=1,count do run(n)end
print('PASS clock policy: durable success and '..count..' injected write/sync/rename/readback faults retain fail-closed marker')
