-- Bounded, dependency-free JSON decoding for Lua 5.1. Core 6.9.8.
local M = {}
M.null = setmetatable({}, { __metatable = "json.null" })
local kinds = setmetatable({}, { __mode = "k" })
local forms = setmetatable({}, { __mode = "k" })
local defaults = { bytes = 16384, depth = 8, nodes = 4096, string_bytes = 16384 }

function M.kind(value)
    if value == M.null then return "null" end
    return kinds[value] or type(value)
end

function M.number_kind(container, key)
    return forms[container] and forms[container][key] or nil
end

local function utf8(cp)
    if cp < 128 then return string.char(cp) end
    if cp < 2048 then return string.char(192 + math.floor(cp / 64), 128 + cp % 64) end
    if cp < 65536 then
        return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
    end
    return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64,
                       128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end

function M.decode(text, options)
    local limits = {}
    if options ~= nil and (type(options) ~= "table" or getmetatable(options) ~= nil) then
        return nil, { code = "limits", offset = 1 }
    end
    for key, value in pairs(options or {}) do
        if not defaults[key] or type(value) ~= "number" or value ~= math.floor(value)
            or value < 1 or value > defaults[key] then
            return nil, { code = "limits", offset = 1 }
        end
    end
    for key, value in pairs(defaults) do limits[key] = (options or {})[key] or value end
    if type(text) ~= "string" then return nil, { code = "input_type", offset = 1 } end
    if #text > limits.bytes then return nil, { code = "bytes", offset = 1 } end
    local i, nodes = 1, 0
    local function fail(code, offset) error({ code = code, offset = offset or i }, 0) end
    local function node()
        nodes = nodes + 1
        if nodes > limits.nodes then fail("nodes") end
    end
    local function whitespace()
        while text:sub(i, i) == " " or text:sub(i, i) == "\t"
            or text:sub(i, i) == "\r" or text:sub(i, i) == "\n" do i = i + 1 end
    end
    local function scalar_length(pos)
        local a, b, c, d = text:byte(pos, pos + 3)
        local function cont(x) return x and x >= 128 and x <= 191 end
        if a < 128 then return 1 end
        if a >= 194 and a <= 223 and cont(b) then return 2 end
        if a >= 224 and a <= 239 and cont(b) and cont(c)
            and (a ~= 224 or b >= 160) and (a ~= 237 or b <= 159) then return 3 end
        if a >= 240 and a <= 244 and cont(b) and cont(c) and cont(d)
            and (a ~= 240 or b >= 144) and (a ~= 244 or b <= 143) then return 4 end
        fail("utf8", pos)
    end
    local function parse_string()
        if text:sub(i, i) ~= '"' then fail("string") end
        i = i + 1
        local chunks, length = {}, 0
        local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                          b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
        local function hex4()
            local hex = text:sub(i, i + 3)
            if #hex ~= 4 or hex:find('[^0-9a-fA-F]') then fail("unicode_escape") end
            i = i + 4
            return tonumber(hex, 16)
        end
        while i <= #text do
            local byte = text:byte(i)
            if byte == 34 then i = i + 1; return table.concat(chunks) end
            local chunk
            if byte == 92 then
                i = i + 1
                local escape = text:sub(i, i)
                i = i + 1
                if escape == 'u' then
                    local cp = hex4()
                    if cp >= 55296 and cp <= 56319 then
                        if text:sub(i, i + 1) ~= '\\u' then fail("surrogate") end
                        i = i + 2
                        local low = hex4()
                        if low < 56320 or low > 57343 then fail("surrogate") end
                        cp = 65536 + (cp - 55296) * 1024 + low - 56320
                    elseif cp >= 56320 and cp <= 57343 then fail("surrogate") end
                    chunk = utf8(cp)
                else
                    chunk = escapes[escape]
                    if not chunk then fail("escape") end
                end
            else
                if byte < 32 then fail("control") end
                local start = i
                repeat
                    i = i + scalar_length(i)
                    byte = text:byte(i)
                until not byte or byte < 32 or byte == 34 or byte == 92
                chunk = text:sub(start, i - 1)
            end
            length = length + #chunk
            if length > limits.string_bytes then fail("string_bytes") end
            chunks[#chunks + 1] = chunk
        end
        fail("unterminated_string")
    end
    local function digit() local c = text:byte(i); return c and c >= 48 and c <= 57 end
    local function parse_number()
        local start, form = i, "integer"
        if text:sub(i, i) == '-' then i = i + 1 end
        if text:sub(i, i) == '0' then
            i = i + 1
            if digit() then fail("number") end
        else
            if not digit() then fail("number") end
            while digit() do i = i + 1 end
        end
        if text:sub(i, i) == '.' then
            form = "number"; i = i + 1
            if not digit() then fail("number") end
            while digit() do i = i + 1 end
        end
        if text:sub(i, i):lower() == 'e' then
            form = "number"; i = i + 1
            if text:sub(i, i) == '+' or text:sub(i, i) == '-' then i = i + 1 end
            if not digit() then fail("number") end
            while digit() do i = i + 1 end
        end
        local value = tonumber(text:sub(start, i - 1))
        if not value or value ~= value or value == math.huge or value == -math.huge then fail("number_range", start) end
        if math.abs(value) > 9007199254740991 then fail("number_range", start) end
        return value, form
    end
    local parse
    parse = function(depth)
        whitespace(); node()
        local char = text:sub(i, i)
        if char == '{' or char == '[' then
            if depth >= limits.depth then fail("depth") end
            local object = char == '{'
            local close = object and '}' or ']'
            local result, seen, number_forms = {}, {}, {}
            kinds[result] = object and "object" or "array"
            forms[result] = number_forms
            i = i + 1; whitespace()
            if text:sub(i, i) == close then i = i + 1; return result end
            local index = 1
            while true do
                local key = index
                if object then
                    node(); key = parse_string()
                    if seen[key] then fail("duplicate_key") end
                    seen[key] = true
                    whitespace()
                    if text:sub(i, i) ~= ':' then fail("colon") end
                    i = i + 1
                end
                local value, form = parse(depth + 1)
                result[key] = value
                number_forms[key] = form
                index = index + 1
                whitespace()
                local delimiter = text:sub(i, i)
                i = i + 1
                if delimiter == close then return result end
                if delimiter ~= ',' then fail("delimiter", i - 1) end
                whitespace()
            end
        elseif char == '"' then return parse_string()
        elseif char == '-' or digit() then return parse_number()
        end
        for word, value in pairs({ ['true'] = true, ['false'] = false, ['null'] = M.null }) do
            if text:sub(i, i + #word - 1) == word then i = i + #word; return value end
        end
        fail("value")
    end
    local ok, value, form = pcall(function()
        local result, number_form = parse(0)
        whitespace()
        if i <= #text then fail("trailing") end
        return result, number_form
    end)
    if not ok then return nil, value end
    return value, nil, form
end

return M
