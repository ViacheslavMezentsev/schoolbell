local method,status='POST',nil
local h={getenv=function()return method end,status=function(s)status=s end,
 header=function()end,prepare_content=function()end,write=function(s)_G.response=s end}
package.loaded['luci.http']=h
-- This endpoint must only observe time; it has no set-clock operation.
local original=os.execute;os.execute=function()error('must not run commands')end
dofile('packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
luci.controller.schoolbell_test.clock();assert(status==405 and response==nil)
method='GET';local before=os.time();luci.controller.schoolbell_test.clock()
local out=require('schoolbell.media_codec').decode(response)
assert(out.ok and out.epoch>=before and out.epoch<=os.time())
local t=os.date('*t',out.epoch)
for _,key in ipairs({'year','month','day','hour','min','sec'})do assert(out[key]==t[key])end
os.execute=original
print('PASS dashboard: GET clock uses router local date; POST rejected; no commands')
