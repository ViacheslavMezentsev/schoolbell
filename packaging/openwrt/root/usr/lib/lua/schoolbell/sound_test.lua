-- Fixed-sample commissioning tool, not the production queue/player adapter.
local M = {}
M.sample = "/usr/share/schoolbell-sound-test/test.mp3"
M.lock = "/tmp/schoolbell-sound-test.lock"
function M.run(io)
    if io.muted and io.muted() then return {ok=false,state="muted"} end
    if not io.ready() then return {ok=false, state="unavailable"} end
    if not io.acquire() then return {ok=false, state="busy"} end
    if io.muted and io.muted() then io.release();return {ok=false,state="muted"} end
    local pid = io.spawn()
    local function finish(state, ok, code)
        if not io.release() then return {ok=false, state="cleanup_required"} end
        return {ok=ok, state=state, exit_code=code}
    end
    if not pid then return finish("spawn_failed", false) end
    local stopped=false
    for i=1,(io.limit or 100) do
        local p, why, code = io.wait(pid)
        if p == pid then
            if stopped then return finish("muted",false,code) end
            return finish(why == "exited" and code == 0 and "completed" or "failed",
                          why == "exited" and code == 0, code)
        end
        -- nil means an uncertain wait error; false means still running.
        if p == nil then return {ok=false, state="recovery_required"} end
        if not stopped and io.muted and io.muted() then io.kill(pid);stopped=true end
        io.sleep()
    end
    io.kill(pid)
    for i=1,20 do
        local p = io.wait(pid)
        if p == pid then return finish("timeout", false) end
        if p == nil then break end
        io.sleep()
    end
    -- Never unlock when the child outcome is unknown.
    return {ok=false, state="recovery_required"}
end
function M.system(media)
    local n, fs = require("nixio"), require("nixio.fs")
    local catalog={test=13104,['0']=41273,['1']=63321,['2']=69904,['3']=68023,['4']=82368}
    media=media or 'test';assert(catalog[media] or require('schoolbell.media_library').editable(media),'unknown media')
    local sample='/usr/share/schoolbell-sound-test/'..media..'.mp3'
    local control=require('schoolbell.controls');local ok,initial=pcall(control.read)
    return {
        limit=620,
        muted=function()local good,current=pcall(control.read);return not ok or not good or current.muted or current.generation~=initial.generation end,
        ready=function()
            return fs.access("/usr/bin/madplay","x") and fs.access("/dev/dsp","w")
        end,
        acquire=function()
            if not fs.mkdir(M.lock,700)then return false end
            local good,path=pcall(function()return require('schoolbell.media_web').resolve(media)end)
            if not good then fs.rmdir(M.lock);return false end
            local st=fs.lstat(path)
            if not st or st.type~='reg' or st.size<1 or st.size>524288 then fs.rmdir(M.lock);return false end
            if path=='/usr/share/schoolbell-sound-test/'..media..'.mp3' and st.size~=catalog[media]then fs.rmdir(M.lock);return false end
            sample=path;return true
        end,
        release=function() return fs.rmdir(M.lock) end,
        spawn=function()
            local pid=n.fork()
            if pid==0 then
                local f=n.open("/dev/null","r+")
                if not f then os.exit(126) end
                if not n.dup(f,n.stdin) or not n.dup(f,n.stdout) or not n.dup(f,n.stderr) then os.exit(126) end
                f:close()
                n.exec("/usr/bin/madplay","--no-tty-control","-a",tostring(ok and initial.volume_db or 0),"-R","48000",
                       "-o","/dev/dsp",sample)
                os.exit(127)
            end
            return pid
        end,
        wait=function(pid) return n.waitpid(pid,"nohang") end,
        sleep=function() n.nanosleep(0,100000000) end,
        kill=function(pid) return n.kill(pid,9) end
    }
end
return M
