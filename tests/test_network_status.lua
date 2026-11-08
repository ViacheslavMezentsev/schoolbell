package.path="src/lua/?.lua;vendor/?.lua;"..package.path
local M=require('schoolbell.network_status')
for _,s in ipairs({'1.1.1.1','time.example.org','ntp-server'})do assert(M.valid_host(s),s)end
for _,s in ipairs({'','-c','a;reboot','a b','.host','host.','a..b','a/b','a\n','a_'})do assert(not M.valid_host(s),s)end
local e={boot='b',process='1:10',uptime=100,stratum=2,epoch=42}
assert(M.ntp_state(false,'1:10',e,'b',110).state=='disabled')
assert(M.ntp_state(true,'',e,'b',110).state=='stopped')
assert(M.ntp_state(true,'1:10',nil,'b',110).state=='waiting')
assert(M.ntp_state(true,'1:10',e,'c',110).state=='waiting')
assert(M.ntp_state(true,'1:11',e,'b',110).state=='waiting')
assert(M.ntp_state(true,'1:10',e,'b',99).state=='waiting')
assert(M.ntp_state(true,'1:10',e,'b',1000).state=='synced')
assert(M.ntp_state(true,'1:10',e,'b',1001).state=='waiting')
e.stratum=16;assert(M.ntp_state(true,'1:10',e,'b',110).state=='waiting');e.stratum=2
local cfg={enabled=true,host='1.1.1.1',valid=true}
local c={boot='b',uptime=100,host=cfg.host,enabled=true,reachable=true,ntp={state='synced',age_seconds=10}}
assert(M.cache_state(c,cfg,'b',110).internet.state=='available')
assert(M.cache_state(c,cfg,'b',251).ntp.state=='unknown')
assert(M.cache_state(c,cfg,'c',110).internet.state=='checking')
c.reachable=false;assert(M.cache_state(c,cfg,'b',110).internet.state=='unconfirmed')
cfg.host='other';assert(M.cache_state(c,cfg,'b',110).internet.state=='checking')
cfg.enabled=false;assert(M.cache_state(c,cfg,'b',110).internet.state=='disabled')
assert(M.cache_state(c,cfg,'b',110).ntp.state=='synced')
cfg.valid=false;assert(M.cache_state(c,cfg,'b',110).ntp.state=='synced')
-- Invalid input never starts a subprocess or writes configuration.
assert(not M.probe('host;reboot'));assert(not M.save(true,'bad host').ok)
local waits,killed,execs=0,false,0
package.loaded.nixio={fork=function()return 7 end,waitpid=function(pid,flag)waits=waits+1;if not flag then return pid,'signaled',9 end;return 0 end,nanosleep=function()end,kill=function(pid,sig)assert(pid==7 and sig==9);killed=true end}
assert(not M.probe('1.1.1.1'));assert(killed and waits==51)
package.loaded.nixio.waitpid=function(pid)return pid,'exited',0 end
assert(M.probe('1.1.1.1'))
print('network status: host validation, independent NTP, cache, reboot/restart/expiry and hard probe timeout PASS')

-- Exercise the real codec and RAM publication, including fractional /proc uptime.
local input={['/proc/uptime']='123.45 0', ['/proc/sys/kernel/random/boot_id']='boot\n'}
local output={};local realopen,rename=io.open,os.rename
io.open=function(path,mode)
 if mode=='w' then return {write=function(_,text)output[path]=text;return true end,close=function()return true end}end
 if input[path]then return {read=function()return input[path]end,close=function()end}end
 return nil
end
os.rename=function(a,b)output[b]=output[a];return true end
local made=false
package.loaded['nixio.fs']={lstat=function()return made and {type='dir'} or nil end,mkdir=function(path,mode)assert(path=='/tmp/schoolbell-network' and mode=='700');made=true;return true end}
package.loaded.nixio.getpid=function()return 1 end
package.loaded.nixio.open=function()return {sync=function()return true end,close=function()end}end
M.processes=function()return '9:100'end
M.event('periodic','2')
local e=require('modbus.json_strict').decode(output['/tmp/schoolbell-network/ntp.json'])
assert(e and e.uptime==123 and e.stratum==2 and e.boot=='boot')
M.event('unsync','2');assert(require('modbus.json_strict').decode(output['/tmp/schoolbell-network/ntp.json']).stratum==16)
M.event('step','2');assert(require('modbus.json_strict').decode(output['/tmp/schoolbell-network/ntp.json']).stratum==16)
assert(M.save(false,'ntp.example.org').ok)
assert(output['/etc/config/schoolbell_network']:find("option enabled '0'",1,true))
assert(output['/etc/config/schoolbell_network']:find("option host 'ntp.example.org'",1,true))
package.loaded.nixio.open=function()error('disk failure')end
assert(not M.save(true,'1.1.1.1').ok)
io.open=realopen;os.rename=rename
print('network persistence: real codec, fractional uptime, event publication, settings and write failure PASS')

package.loaded['luci.model.uci']={cursor=function()return {get=function(_,config,section,key)return false,'Entry not found'end}end}
local defaults=M.config();assert(defaults.enabled and defaults.host=='1.1.1.1' and defaults.valid)
print('network config: LuCI UCI missing package defaults PASS')
