local length,allowed,calls,status="999999",false,0,nil
local h={
 getenv=function(k)
  if k=="CONTENT_LENGTH" then return length end
  if k=="CONTENT_TYPE" then return "application/x-www-form-urlencoded" end
  return "POST"
 end,
 status=function(value)status=value end,
 formvalue=function()error("must not decode untrusted body")end
}
package.loaded["luci.http"]=h
package.loaded["luci.dispatcher"]={test_post_security=function()calls=calls+1;return allowed end}
dofile("packaging/openwrt/root/usr/lib/lua/luci/controller/schoolbell_test.lua")
luci.controller.schoolbell_test.preview()
assert(status==413 and calls==0)
length="100";luci.controller.schoolbell_test.preview();assert(calls==1)
print("PASS annual HTTP: oversized body and rejected CSRF never reach preview")
