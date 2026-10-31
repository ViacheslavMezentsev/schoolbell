local N=require('schoolbell.clock_linux')
local System=require('schoolbell.clock_system')
local Model=require('schoolbell.clock_trust')
local C=require('schoolbell.clock_reference')
local root=assert(arg[1]);local mode=arg[2] or 'normal'
local function record()return {format='schoolbell-clock/1',source='manual',confirmed_utc_ms=1790000000000,checkpoint_utc_ms=1790000000000}end
local function ports()return System.new(root,function()return 'host-observer-1' end)end
if mode=='open-fail'then assert(not pcall(N.open,root));return end
if mode=='load-fail'then assert(not ports().store.load().ok);return end
if mode=='save-fail'then assert(not ports().store.save(record(),'empty').ok);return end
if mode=='lock'then local h=N.open(root);io.write('locked\n');io.flush();io.read('*l');h:close();return end
if mode=='orphan'then local s=ports().store;assert(s.load().revision=='empty');assert(s.save(record(),'empty').ok);return end
local epoch=0
local changing=System.new(root,function()epoch=epoch+1;return tostring(epoch)end)
assert(not pcall(changing.clock))
assert(changing.valid_utc(0) and changing.valid_utc(2147483647999))
assert(not changing.valid_utc(-1) and not changing.valid_utc(2147483648000) and not changing.valid_utc(0.5))
local a,b=N.resolution();assert(a>0 and b>0 and a<=1 and b<=1)
local io=ports();local model=Model.new(io);assert(not model.admit())
local p=io.clock();assert(p.before_ms<=p.after_ms and p.after_ms-p.before_ms<=100 and p.utc_ms%1==0)
assert(math.abs(p.utc_ms/1000-os.time())<2)
local q=assert(model.request_confirmation());assert(model.confirm(q.token).ok);assert(not model.admit())
assert(model.enable().ok)
for i=1,1000 do assert(model.admit())end -- same-millisecond/overlapping brackets
model.disable();assert(not model.admit())
local restart=Model.new(ports());assert(not restart.admit())
local store=io.store;local old=store.load();assert(old.ok and old.data)
assert(store.save(record(),'wrong').code=='conflict')
local h=N.open(root);assert(not pcall(N.open,root));assert(h:close() and h:close());assert(not pcall(h.read,h,'clock-reference.json'))
h=N.open(root);assert(not pcall(h.read,h,'../outside'));assert(not pcall(h.write,h,'clock-reference.next',string.rep('x',1025)));h:close()
h=N.open(root);h=nil;collectgarbage('collect');h=N.open(root);h:close()
if N.inject then
 local baseline=N.fd_count()
 for _,fault in ipairs({'openat','close','flock','read','write','renameat','fsync'})do
  for count=1,12 do
   N.inject(fault,count)
   local result=store.save(record(),store.load().revision)
   N.inject('',1);collectgarbage('collect')
   assert(N.fd_count()==baseline,'leak '..fault..' '..count)
   assert(store.load().ok,'invalid committed state '..fault)
   if result.ok then assert(result.revision==select(2,C.encode(record())))end
  end
 end
 N.inject('partial');assert(store.save(record(),store.load().revision).ok);N.inject('')
 for _,fault in ipairs({'clock_gettime','clock_getres','coarse'})do
  local count=fault=='clock_gettime' and 3 or (fault=='clock_getres' and 2 or 1)
  for index=1,count do N.inject(fault,index);assert(not pcall(function()local s=ports();s.clock()end));N.inject('')end
 end
 -- A read error must revoke existing trust without changing the real clocks.
 local m=Model.new(ports());local token=m.request_confirmation();assert(m.confirm(token.token,true).ok);assert(m.enable().ok)
 N.inject('clock_gettime');assert(not m.admit());N.inject('')
 assert(N.fd_count()==baseline)
end
print('clock system: real clocks/store, restart, CAS, locks, GC and bounded access PASS')
