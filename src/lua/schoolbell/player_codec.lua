-- schoolbell 3.6.25/29: fixed SBPE v1 frame; pure Lua 5.1.
local M = {}
local stages = {[5]="stdio", [8]="exec", [10]="cleanup"}
local numbers = {stdio=5, exec=8, cleanup=10}
local function integer(n, lo, hi)
    return type(n)=="number" and n==n and n>=lo and n<=hi and n==math.floor(n)
end
local function failure() return nil, {code="protocol_error", stage="pipe"} end
function M.encode(stage, errno)
    local n = numbers[stage]
    if not n or not integer(errno,1,4095) then return failure() end
    return "SBPE"..string.char(1,1,0,n,0,0,math.floor(errno/256),errno%256,0,0,0,0)
end
function M.decode(bytes)
    if type(bytes)~="string" or #bytes~=16 or bytes:sub(1,4)~="SBPE" then return failure() end
    local version,kind,hi,stage,a,b,c,d,z1,z2,z3,z4 = bytes:byte(5,16)
    local errno = ((a*256+b)*256+c)*256+d
    if version~=1 or kind~=1 or hi~=0 or not stages[stage] or
       not integer(errno,1,4095) or z1+z2+z3+z4~=0 then return failure() end
    return {stage=stages[stage], errno=errno}
end
function M.decoder()
    local bytes, ended, broken = "", false, false
    return {
        feed=function(chunk,eof)
            if broken or ended or type(chunk)~="string" or type(eof)~="boolean" or #chunk>16 then
                broken=true; return failure()
            end
            if #bytes+#chunk>16 then broken=true; return failure() end
            bytes=bytes..chunk
            local frame
            if #bytes==16 then
                frame=M.decode(bytes)
                if not frame then broken=true; return failure() end
            end
            if eof then
                ended=true
                if #bytes>0 and #bytes<16 then broken=true; return failure() end
            end
            -- A valid frame is observable before EOF; a later extra byte is still an error.
            return {frame=frame,eof=ended}
        end
    }
end
return M
