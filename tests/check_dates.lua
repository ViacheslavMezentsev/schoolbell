package.path="./src/lua/?.lua;"..package.path
local cal=require("schoolbell.calendar")
local resolve=assert(cal.fixed_offset("fixture",345))
local count=0
for line in io.lines(assert(arg[1])) do
    local date,weekday,previous,next_date,utc=line:match("^(%S+) (%d) (%S+) (%S+) (%S+)$")
    assert(cal.weekday(date)==tonumber(weekday),date)
    assert(cal.add_days(date,-1)==previous,date)
    assert(cal.add_days(date,1)==next_date,date)
    assert(resolve("fixture",date,"12:34")[1]==tonumber(utc),date)
    count=count+1
end
assert(count>=14400)
print("[schoolbell-date-oracle] PASS: "..count.." independent date vectors")
