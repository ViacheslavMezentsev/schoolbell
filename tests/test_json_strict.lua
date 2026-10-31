package.path = "./vendor/?.lua;./vendor/?/init.lua;" .. package.path
local json = require("modbus.json_strict")
local count = 0
local function test(name, fn)
    fn(); count = count + 1; print("[strict-json] OK " .. name)
end
local function decode(text, options)
    local value, err, form = json.decode(text, options)
    assert(err == nil, err and err.code)
    return value, form
end
local function bad(text, code, options)
    local value, err = json.decode(text, options)
    assert(value == nil and type(err) == "table", "expected rejection")
    assert(type(err.offset) == "number" and err.offset >= 1)
    if code then assert(err.code == code, err.code .. " != " .. code) end
end

test("no LuCI dependency (standalone decoder)", function()
    package.preload["luci.jsonc"] = function() error("must not load LuCI") end
    local value, err = json.decode('{"a":1}')
    assert(not err and value.a == 1)
    assert(package.loaded["luci.jsonc"] == nil)
end)
test("scalar types and explicit null", function()
    assert(decode('true') == true and decode('false') == false)
    assert(decode('null') == json.null)
    assert(json.kind(json.null) == 'null')
    assert(decode('"abc"') == 'abc')
end)
test("empty containers remain distinct", function()
    assert(json.kind(decode('{}')) == 'object')
    assert(json.kind(decode('[]')) == 'array')
end)
test("null preserves dense array and object membership", function()
    local v = decode('{"a":[null,false,2],"b":null}')
    assert(#v.a == 3 and v.a[1] == json.null and v.a[2] == false and v.b == json.null)
end)
test("number syntax metadata", function()
    local v = decode('{"i":0,"f":0.0,"e":1e0,"n":-1,"a":[2.0]}')
    assert(json.number_kind(v, 'i') == 'integer')
    assert(json.number_kind(v, 'f') == 'number' and json.number_kind(v, 'e') == 'number')
    assert(json.number_kind(v.a, 1) == 'number')
    local _, form = decode('1e0'); assert(form == 'number')
end)
test("valid numbers", function()
    assert(decode('-12') == -12 and decode('1.25') == 1.25)
    assert(decode('2E+2') == 200 and decode('-0.25e-1') == -0.025)
    assert(decode('9007199254740991') == 9007199254740991)
end)
test("invalid and out-of-range numbers", function()
    for _, text in ipairs({'01','-01','+1','.1','1.','1e','1e+','--1','0x10',
                           'NaN','Infinity','-Infinity','1e9999','9007199254740992'}) do bad(text) end
end)
test("duplicate keys including escaped aliases", function()
    bad('{"a":1,"a":2}', 'duplicate_key')
    bad([=[{"a":null,"\u0061":3}]=], 'duplicate_key')
    bad('{"x":{"a":false,"a":2}}', 'duplicate_key')
    bad([=[{"é":1,"\u00e9":2}]=], 'duplicate_key')
    decode('{"x":{"a":1},"y":{"a":2}}')
end)
test("legal escapes", function()
    local bs = string.char(92)
    local input = '"' .. bs .. '"' .. bs .. bs .. bs .. '/' .. bs .. 'b' .. bs .. 'f' .. bs .. 'n' .. bs .. 'r' .. bs .. 't' .. '"'
    assert(decode(input) == string.char(34,92,47,8,12,10,13,9))
    assert(decode('"' .. bs .. 'u0000"') == string.char(0))
end)
test("unicode and paired surrogates", function()
    assert(decode('"Привет"') == 'Привет')
    assert(decode([=["\uD83D\uDE00"]=]) == string.char(240,159,152,128))
    assert(decode([=["\udbff\udfff"]=]) == string.char(244,143,191,191))
    assert(decode([=["\u20AC"]=]) == string.char(226,130,172))
end)
test("bad escapes surrogates and controls", function()
    for _, text in ipairs({[=["\q"]=],[=["\u12"]=],[=["\uGGGG"]=],[=["\ud800"]=],
                           [=["\ud800\u0041"]=],[=["\udc00"]=],'"unterminated', '"a\
"', '"' .. string.char(0) .. '"'}) do bad(text) end
end)
test("malformed UTF-8", function()
    for _, bytes in ipairs({{128}, {192,128}, {194}, {224,128,128}, {237,160,128},
                            {240,128,128,128}, {244,144,128,128}, {245,128,128,128}, {255}}) do
        bad('"' .. string.char(unpack(bytes)) .. '"', 'utf8')
    end
end)
test("structure whitespace and no extensions", function()
    assert(decode(' \t\r\n [ 1 , 2 ] \n')[2] == 2)
    for _, text in ipairs({'',' ','[1,]','{"a":1,}','{a:1}','{"a" 1}',
                          '[1 2]','true false','{}x','// comment\n{}',
                          string.char(239,187,191)..'{}'}) do bad(text) end
end)
test("raw byte limit", function()
    decode('[]' .. string.rep(' ', 16382))
    bad('[]' .. string.rep(' ', 16383), 'bytes')
    decode('{}', {bytes=2}); bad('{} ', 'bytes', {bytes=2})
end)
test("depth boundary", function()
    decode(string.rep('[',8)..'0'..string.rep(']',8))
    bad(string.rep('[',9)..'0'..string.rep(']',9), 'depth')
    decode('{"a":[{}]}', {depth=3})
    bad('{"a":[{}]}', 'depth', {depth=2})
end)
test("node count includes keys", function()
    decode('{"a":0}', {nodes=3}); bad('{"a":0}', 'nodes', {nodes=2})
    decode('[0,0]', {nodes=3}); bad('[0,0]', 'nodes', {nodes=2})
end)
test("decoded string byte limit", function()
    decode([=["\u00e9"]=], {string_bytes=2})
    bad([=["\u00e9"]=], 'string_bytes', {string_bytes=1})
    bad('{"aa":0}', 'string_bytes', {string_bytes=1})
end)
test("limits cannot be raised or malformed", function()
    for _, limits in ipairs({{bytes=16385},{depth=9},{nodes=0},{bytes=true},
                             {extra=1},{depth=1.5},{nodes=math.huge}}) do bad('{}', 'limits', limits) end
    bad('{}', 'limits', false)
    bad('{}', 'limits', setmetatable({}, {}))
    bad(false, 'input_type')
end)
test("error isolation and no partial result", function()
    bad('{"good":1,"broken":'); local v = decode('{"good":2}')
    assert(v.good == 2)
    assert(json.number_kind({}, 'good') == nil)
end)
test("all control characters and truncations", function()
    for i=0,31 do bad('"'..string.char(i)..'"') end
    local text = [=[{"a":[true,false,null,"\uD83D\uDE00",-1.2e3]}]=]
    for i=1,#text-1 do bad(text:sub(1,i)) end
    decode(text)
end)
print('[test_json_strict] OK: ' .. count .. ' cases')
