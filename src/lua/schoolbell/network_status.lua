-- Advisory network/time observations. Never gates or changes automatic bells.
local J=require('modbus.json_strict')
local C=require('schoolbell.media_codec')
local M={interval=60,cache_ttl=150,ntp_ttl=900,default_host='1.1.1.1'}
local root='/tmp/schoolbell-network'
local function read(path,limit)
 local f=io.open(path,'r');if not f then return nil end
 local s=f:read((limit or 4096)+1);f:close();if not s or #s>(limit or 4096)then return nil end;return s
end
local function decode(s)local ok,v=pcall(J.decode,s or '');return ok and type(v)=='table' and v or nil end
function M.valid_host(s)
 if type(s)~='string' or #s<1 or #s>253 or s:find('[^%w%.%-]') or (s:sub(1,1)=='-' or s:sub(1,1)=='.') or s:sub(-1)=='.' or s:find('%.%.') then return false end
 for label in s:gmatch('[^.]+')do if #label>63 or not label:match('^%w') or not label:match('%w$')then return false end end
 return true
end
function M.config()
 local u=require('luci.model.uci').cursor();local enabled=u:get('schoolbell_network','probe','enabled');local host=u:get('schoolbell_network','probe','host') or M.default_host
 return {enabled=enabled~='0',host=host,valid=M.valid_host(host)}
end
function M.save(enabled,host)
 if type(enabled)~='boolean' or not M.valid_host(host) then return {ok=false,code='invalid'}end
 local ok=pcall(function()
  local n=require('nixio');local target='/etc/config/schoolbell_network';local tmp=target..'.'..n.getpid()..'.tmp'
  local f=assert(io.open(tmp,'w'));assert(f:write("config probe 'probe'\n option enabled '"..(enabled and '1' or '0').."'\n option host '"..host.."'\n"));assert(f:close())
  local fd=assert(n.open(tmp,'r'));assert(fd:sync());fd:close();assert(os.rename(tmp,target))
 end)
 return {ok=ok,code=not ok and 'save_failed' or nil}
end
function M.uptime()return math.floor(tonumber((read('/proc/uptime',128) or ''):match('^(%d+%.?%d*)')) or 0) end
function M.boot()return (read('/proc/sys/kernel/random/boot_id',64) or ''):match('^%s*(.-)%s*$')end
function M.processes()
 local fs=require('nixio.fs');local out={}
 for name in fs.dir('/proc')do
  if name:match('^%d+$') and (read('/proc/'..name..'/comm',64) or ''):match('^ntpd\n?$')then
   local stat=read('/proc/'..name..'/stat',4096) or '';local fields={}
   for s in (stat:match('^%d+ %b() (.*)') or ''):gmatch('%S+')do fields[#fields+1]=s end
   if fields[20]then out[#out+1]=name..':'..fields[20]end
  end
 end
 table.sort(out);return table.concat(out,',')
end
local function write(name,v)
 local fs=require('nixio.fs');local n=require('nixio');local st=fs.lstat(root)
 if not st then assert(fs.mkdir(root,'700'));st=assert(fs.lstat(root))end
 assert(st.type=='dir');local tmp=root..'/'..name..'.'..n.getpid()..'.tmp'
 local f=assert(io.open(tmp,'w'));assert(f:write(C.encode(v)));assert(f:close());assert(os.rename(tmp,root..'/'..name))
end
function M.event(action,stratum)
 -- step runs before stratum settles: do not treat it as proof of synchronization.
 if action~='stratum' and action~='periodic' and action~='unsync' and action~='step' then return end
 local st=(action=='unsync' or action=='step') and 16 or tonumber(stratum);if not st or st%1~=0 or st<0 or st>16 then return end
 write('ntp.json',{boot=M.boot(),uptime=M.uptime(),epoch=os.time(),process=M.processes(),stratum=st})
end
function M.ntp_state(enabled,process,event,boot,up)
 if not enabled then return {state='disabled'}end
 if process=='' then return {state='stopped'}end
 if type(event)~='table' or event.boot~=boot or event.process~=process or type(event.uptime)~='number' or up<event.uptime then return {state='waiting'}end
 local age=math.floor(up-event.uptime)
 local synced=age<=M.ntp_ttl and type(event.stratum)=='number' and event.stratum>=1 and event.stratum<=15
 return {state=synced and 'synced' or 'waiting',age_seconds=age,confirmed_epoch=event.epoch}
end
function M.cache_state(cache,cfg,boot,up)
 local out={config=cfg,internet={state=cfg.enabled and 'checking' or 'disabled'},ntp={state='unknown'}}
 if cfg.enabled and not cfg.valid then out.internet.state='unknown' end
 if type(cache)~='table' or cache.boot~=boot or type(cache.uptime)~='number' or up<cache.uptime then return out end
 if up-cache.uptime>M.cache_ttl then if cfg.enabled then out.internet.state='unknown' end;return out end
 local age=math.floor(up-cache.uptime);if type(cache.ntp)=='table' then for k,v in pairs(cache.ntp)do out.ntp[k]=v end end
 if out.ntp.age_seconds then out.ntp.age_seconds=out.ntp.age_seconds+age;if out.ntp.state=='synced' and out.ntp.age_seconds>M.ntp_ttl then out.ntp.state='waiting'end end
 if cfg.enabled and cfg.valid and cache.host==cfg.host and cache.enabled==true then out.internet={state=cache.reachable and 'available' or 'unconfirmed',age_seconds=age,host=cache.host}end
 return out
end
function M.snapshot()
 local ok,r=pcall(function()return M.cache_state(decode(read(root..'/cache.json')),M.config(),M.boot(),M.uptime())end)
 return ok and r or {internet={state='unknown'},ntp={state='unknown'}}
end
function M.probe(host)
 if not M.valid_host(host)then return false end
 local n=require('nixio');local pid=n.fork();if not pid then return false end
 if pid==0 then
  local f=n.open('/dev/null','r+');if not f then os.exit(126)end
  n.dup(f,n.stdin);n.dup(f,n.stdout);n.dup(f,n.stderr);f:close()
  n.exec('/bin/ping','-c','1','-W','3',host);os.exit(127)
 end
 for _=1,50 do
  local got,why,code=n.waitpid(pid,'nohang');if got and got>0 then return why=='exited' and code==0 end
  n.nanosleep(0,100000000)
 end
 n.kill(pid,9);n.waitpid(pid);return false
end
function M.tick()
 local cfg=M.config();local reach=cfg.enabled and cfg.valid and M.probe(cfg.host) or false
 local up=M.uptime();local boot=M.boot();local u=require('luci.model.uci').cursor()
 local ntp=M.ntp_state(u:get('system','ntp','enabled')~='0',M.processes(),decode(read(root..'/ntp.json')),boot,up)
 write('cache.json',{boot=boot,uptime=up,epoch=os.time(),host=cfg.host,enabled=cfg.enabled,reachable=reach,ntp=ntp})
end
return M
