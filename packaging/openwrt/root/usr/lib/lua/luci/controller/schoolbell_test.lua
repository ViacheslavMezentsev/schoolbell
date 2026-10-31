module("luci.controller.schoolbell_test", package.seeall)
function index()
    local page=entry({"admin","schoolbell"},call("page"),"Schoolbell",70)
    page.dependent=false
    entry({"admin","schoolbell","plan-export"},call("plan_export")).leaf=true
    entry({"admin","schoolbell","plan-import"},call("plan_import")).leaf=true
    entry({"admin","schoolbell","session"},call("session")).leaf=true
    entry({"admin","schoolbell","backup"},call("backup")).leaf=true
    entry({"admin","schoolbell","media"},call("media")).leaf=true
    entry({"admin","schoolbell","automatic"},call("automatic")).leaf=true
    entry({"admin","schoolbell","controls"},call("controls")).leaf=true
    entry({"admin","schoolbell","manual"},call("manual")).leaf=true
    entry({"admin","schoolbell","journal"},call("journal")).leaf=true
    entry({"admin","schoolbell","timezone"},call("timezone")).leaf=true
    entry({"admin","schoolbell","clock-trust"},call("clock_trust")).leaf=true
    entry({"admin","schoolbell","clock"},call("clock")).leaf=true
    entry({"admin","schoolbell","preview"},call("preview")).leaf=true
    entry({"admin","schoolbell","schedules"},call("schedules")).leaf=true
    entry({"admin","schoolbell","save-schedules"},call("save_schedules")).leaf=true
    entry({"admin","schoolbell","sample"},call("sample")).leaf=true
    entry({"admin","schoolbell","play"},call("play")).leaf=true
end
local function editor()
    -- Private bundled dependencies; installed core modules remain untouched.
    local path="/usr/share/schoolbell-editor/lua/?.lua;"
    if not package.path:find(path,1,true) then package.path=path..package.path end
    return require("schoolbell.schedule_store"),require("schoolbell.media_codec")
end
local function respond(result)
    local h=require("luci.http")
    h.header("Cache-Control","no-store")
    h.prepare_content("application/json")
    local _,codec=editor()
    h.write(codec.encode(result))
end
-- Uses the inherited LuCI admin session; never accepts a client-supplied SID.
function session()
    local h=require('luci.http');local d=require('luci.dispatcher')
    local method=h.getenv('REQUEST_METHOD')
    if method~='GET' and method~='POST' then h.status(405,'Method Not Allowed');return end
    if not d.context.authsession or not d.context.authuser or not d.context.authtoken then
        h.status(401,'Unauthorized');respond({ok=false,code='auth'});return
    end
    if method=='POST' then
        if not d.test_post_security() then return end
        if h.formvalue('action')~='logout' then h.status(400,'Bad Request');return end
        local ubus=require('luci.util').ubus
        -- Empty successful ubus replies need not contain a Lua table.
        -- Confirm that this server-owned SID no longer exists; never infer this from nil alone.
        local called,result,err=pcall(ubus,'session','destroy',{ubus_rpc_session=d.context.authsession})
        local checked,remaining,lookup_error=false,nil,nil
        if called and (err==nil or err==0) then
            checked,remaining,lookup_error=pcall(ubus,'session','get',{ubus_rpc_session=d.context.authsession})
        end
        if not checked or remaining~=nil or lookup_error~=4 then
            h.status(503,'Unavailable');respond({ok=false,code='logout_uncertain'});return
        end
        h.header('Set-Cookie','sysauth=; expires=Thu, 01 Jan 1970 01:00:00 GMT; path='..d.build_url())
        respond({ok=true,logged_out=true});return
    end
    respond({ok=true,user=d.context.authuser,token=d.context.authtoken})
end
local function audit(action,result)
    local ok,value=pcall(function()editor();return require('schoolbell.journal').request('/etc/schoolbell-editor',action)end)
    if result and (not ok or not value.ok) then result.journal_warning=true end
end
function journal()
    local h=require('luci.http')
    if h.getenv('REQUEST_METHOD')~='GET' then h.status(405,'Method Not Allowed');return end
    editor();respond(require('schoolbell.journal').request('/etc/schoolbell-editor'))
end
function clock_trust()
 local h=require('luci.http');local d=require('luci.dispatcher');local method=h.getenv('REQUEST_METHOD')
 if method~='GET' and method~='POST'then h.status(405,'Method Not Allowed');return end
 if method=='POST'then
  local size=tonumber(h.getenv('CONTENT_LENGTH'))
  if not size or size<1 or size>1024 or not (h.getenv('CONTENT_TYPE') or ''):match('^application/x%-www%-form%-urlencoded')then h.status(413,'Unsupported request');return end
  if not d.test_post_security()then return end
 end
 local _,C=editor();local session=d.context.authsession
 if type(session)~='string' or #session==0 then h.status(403,'Forbidden');return end
 local owner=C.sha(session);local m=require('schoolbell.clock_mailbox').system()
 if method=='GET'then respond(m.poll(h.formvalue('operation',true),owner));return end
 respond(m.submit({id=h.formvalue('operation'),owner=owner,action=h.formvalue('action'),challenge=h.formvalue('challenge'),ack=h.formvalue('ack'),enforced=h.formvalue('enforced'),revision=h.formvalue('revision'),generation=h.formvalue('generation'),epoch=h.formvalue('epoch')}))
end
function timezone()
    local h=require('luci.http');local method=h.getenv('REQUEST_METHOD')
    if method=='GET' then editor();respond(require('schoolbell.timezone').run());return end
    if method~='POST' then h.status(405,'Method Not Allowed');return end
    local size=tonumber(h.getenv('CONTENT_LENGTH'))
    if not size or size<1 or size>2048 or not (h.getenv('CONTENT_TYPE') or ''):match('^application/x%-www%-form%-urlencoded')then h.status(413,'Unsupported request');return end
    if not require('luci.dispatcher').test_post_security()then return end
    editor();local zone=h.formvalue('zone');if not zone then respond({ok=false,code='invalid_zone'});return end
    local value=require('schoolbell.timezone').run(zone,h.formvalue('revision'))
    audit(value.ok and 'timezone_ok' or 'timezone_failed',value);respond(value)
end
function automatic()
 local h=require('luci.http');local method=h.getenv('REQUEST_METHOD')
 if method~='GET' and method~='POST' then h.status(405,'Method Not Allowed');return end
 if method=='POST' then
  local size=tonumber(h.getenv('CONTENT_LENGTH'))
  if not size or size<1 or size>1024 or not (h.getenv('CONTENT_TYPE') or ''):match('^application/x%-www%-form%-urlencoded')then h.status(413,'Unsupported request');return end
  if not require('luci.dispatcher').test_post_security()then return end
  local enabled=h.formvalue('enabled');if enabled~='true' and enabled~='false' then respond({ok=false,code='invalid'});return end
  if enabled=='true'then respond({ok=false,code='use_clock_command'});return end
  editor();local m=require('schoolbell.automatic_store')
  local gate=require('schoolbell.sound_test').lock;local fs=require('nixio.fs');local acquired=false
  if enabled=='true' then acquired=fs.mkdir(gate,700);if not acquired then respond({ok=false,code='busy'});return end end
  local safe,result=pcall(function()
   if acquired then
    local saved=require('schoolbell.schedule_store').request('/etc/schoolbell-editor','load')
    if not saved.ok or not require('schoolbell.media_web').plan_ready(saved.data)then return {ok=false,code='missing_media'}end
   end
   return m.transaction(m.change,enabled=='true',h.formvalue('revision'),m.environment())
  end)
  if acquired and not fs.rmdir(gate)then safe=false end
  if not safe then result={ok=false,code='automatic_storage'}end
  audit(result.ok and (enabled=='true' and 'auto_enabled' or 'auto_disabled') or 'auto_blocked',result)
  -- Never echo the private snapshot or internal storage error to the browser.
  respond({ok=result.ok,code=result.code,generation=result.ok and result.state.generation or nil});return
 end
 editor();local m=require('schoolbell.automatic_store')
 local ok,result=pcall(function()
  assert(not require('nixio.fs').lstat(m.root..'/package.pending'),'package_pending')
  return require('schoolbell.automatic_status').read(m.raw())
 end)
 if ok then local measured,metrics=pcall(function()return require('schoolbell.queue_metrics').read()end);result.queue=measured and metrics or {available=false};local cpu_ok,cpu=pcall(function()return require('schoolbell.system_metrics').read()end);result.cpu=cpu_ok and cpu or {available=false}end
 respond(ok and result or {ok=false,state='unavailable'})
end
function controls()
 local h=require('luci.http');local method=h.getenv('REQUEST_METHOD');local value,volume
 if method~='GET' then
  if method~='POST' then h.status(405,'Method Not Allowed');return end
  local size=tonumber(h.getenv('CONTENT_LENGTH'))
  if not size or size<1 or size>1024 or not (h.getenv('CONTENT_TYPE') or ''):match('^application/x%-www%-form%-urlencoded')then h.status(413,'Unsupported request');return end
  if not require('luci.dispatcher').test_post_security()then return end
  local v=h.formvalue('muted');local gain=h.formvalue('volume_db')
  if gain~=nil then
   if v~=nil or not gain:match('^%-?%d+$') or not tonumber(gain) or tonumber(gain)<-60 or tonumber(gain)>0 then respond({ok=false,code='invalid'});return end
   volume=tonumber(gain)
  else
   if v~='true' and v~='false' then respond({ok=false,code='invalid'});return end
   value=v=='true'
  end
 end
 editor();local m=require('schoolbell.controls');local result=value==nil and volume==nil and m.snapshot() or m.request(value,nil,volume)
 result.playing=require('nixio.fs').lstat(require('schoolbell.sound_test').lock)~=nil
 if volume~=nil then audit(result.ok and 'volume_ok' or 'volume_failed',result)end
 if value~=nil then audit(result.ok and (value and 'mute_on' or 'mute_off') or 'mute_failed',result)end
 respond(result)
end
function manual()
 if not require('luci.dispatcher').test_post_security()then return end
 local store=editor();local saved=store.request('/etc/schoolbell-editor','load')
 if not saved.ok then respond({ok=false,state='unavailable'});return end
 local m=require('schoolbell.sound_test');audit('manual_requested')
 local ok,result=pcall(function()return m.run(m.system(saved.data.manual_media or 'test'))end)
 if not ok then result={ok=false,state='recovery_required'}end
 audit(result.ok and 'play_ok' or 'play_failed',result);respond(result)
end
function clock()
    local h=require('luci.http')
    if h.getenv('REQUEST_METHOD')~='GET' then h.status(405,'Method Not Allowed');return end
    local zone
    local f=io.popen('/sbin/uci -q get system.@system[0].zonename 2>/dev/null','r')
    if f then local value=f:read(129) or '';f:close();value=value:gsub('[\r\n]+$','');if #value>0 and #value<=128 and not value:find('[%c]')then zone=value end end
    local now=os.time()
    local t=os.date('*t',now)
    respond({ok=true,zone=zone,epoch=now,year=t.year,month=t.month,day=t.day,
        hour=t.hour,min=t.min,sec=t.sec})
end
local function module_version()
    local f=io.open('/usr/share/schoolbell-editor/VERSION','rb')
    if not f then return 'неизвестна' end
    local value=f:read(64) or '';f:close()
    return value:match('^(%d+%.%d+%.%d+)\n$') or 'неизвестна'
end
function schedules()
    if require("luci.http").getenv("REQUEST_METHOD")~="GET" then
        require("luci.http").status(405,"Method Not Allowed"); return
    end
    local store=editor()
    respond(store.request("/etc/schoolbell-editor","load"))
end
function save_schedules()
    local h=require("luci.http")
    -- Bound form decoding before requesting token/form values.
    local length=tonumber(h.getenv("CONTENT_LENGTH"))
    local content=h.getenv("CONTENT_TYPE") or ""
    if not length or length<1 or length>49152
       or not content:match("^application/x%-www%-form%-urlencoded") then
        h.status(413,"Unsupported or oversized request"); return
    end
    if not require("luci.dispatcher").test_post_security() then return end
    local store=editor()
    local value=store.request('/etc/schoolbell-editor','save',h.formvalue('draft'),h.formvalue('revision'))
    audit(value.ok and 'save_ok' or 'save_failed',value)
    if not value.ok and value.code~='invalid' and value.code~='conflict' then audit('storage_error',value)end
    respond(value)
end
function preview()
    local h=require("luci.http")
    -- Bound form decoding before requesting token/form values.
    local length=tonumber(h.getenv("CONTENT_LENGTH"))
    local content=h.getenv("CONTENT_TYPE") or ""
    if not length or length<1 or length>49152
       or not content:match("^application/x%-www%-form%-urlencoded") then
        h.status(413,"Unsupported or oversized request"); return
    end
    if not require("luci.dispatcher").test_post_security() then return end
    local store=editor()
    local value=store.preview(h.formvalue('draft'),h.formvalue('date'));audit(value.ok and 'preview_ok' or 'preview_failed',value);respond(value)
end
local function installed_version(package_name)
    local f=io.open('/usr/lib/opkg/info/'..package_name..'.control','rb')
    if not f then return 'не установлен / нет метаданных' end
    local text=f:read(4096) or '';f:close()
    return ('\n'..text):match('\nVersion: ([^\r\n]+)') or 'неизвестна'
end
function page()
    local d=require("luci.dispatcher")
    require("luci.http").header("Cache-Control","no-store")
    require("luci.template").render("schoolbell_test",{
        session_url=d.build_url('admin','schoolbell','session'),
        login_url=d.build_url('admin','schoolbell'),
        auth_user=d.context.authuser or '',
        plan_export_url=d.build_url('admin','schoolbell','plan-export'),
        plan_import_url=d.build_url('admin','schoolbell','plan-import'),
        backup_url=d.build_url('admin','schoolbell','backup'),
        media_url=d.build_url('admin','schoolbell','media'),
        trust_url=d.build_url('admin','schoolbell','clock-trust'),
        automatic_url=d.build_url('admin','schoolbell','automatic'),
        controls_url=d.build_url('admin','schoolbell','controls'),
        manual_url=d.build_url('admin','schoolbell','manual'),
        journal_url=d.build_url('admin','schoolbell','journal'),
        clock_url=d.build_url('admin','schoolbell','clock'),
        timezone_url=d.build_url('admin','schoolbell','timezone'),
        play_url=d.build_url("admin","schoolbell","play"),
        sample_url=d.build_url("admin","schoolbell","sample"),
        preview_url=d.build_url("admin","schoolbell","preview"),
        schedules_url=d.build_url("admin","schoolbell","schedules"),
        save_url=d.build_url("admin","schoolbell","save-schedules"),
        core_version=installed_version('modbus-rtu-core'),
        module_version=module_version(),
        token=d.context.authtoken
    })
end
function media()
 local h=require('luci.http');editor();local m=require('schoolbell.media_web')
 if h.getenv('REQUEST_METHOD')=='GET'then local op=h.formvalue('operation',true);respond(op and m.lookup(op) or m.list());return end
 if h.getenv('REQUEST_METHOD')~='POST'then h.status(405,'Method Not Allowed');return end
 -- uhttpd 19.07 CGI forwards Authorization, but drops arbitrary X-* headers.
 -- Cookie session is still required; Bearer carries its CSRF token, not a login.
 local token=(h.getenv('HTTP_AUTHORIZATION') or ''):match('^Bearer ([^%s]+)$');local expected=require('luci.dispatcher').context.authtoken
 if type(token)~='string' or token=='' or token~=expected then h.status(403,'Forbidden');return end
 local size=tonumber(h.getenv('CONTENT_LENGTH'))
 if not size or size<1 or size>524288 or h.getenv('CONTENT_TYPE')~='application/octet-stream'then h.status(413,'Unsupported request');return end
 local result=m.upload({id=h.formvalue('id',true),name=h.formvalue('name',true),title=h.formvalue('title',true),generation=tonumber(h.formvalue('generation',true)),operation=h.formvalue('operation',true),size=size},h.source())
 audit(result.ok and 'media_ok' or 'media_failed',result);respond(result)
end
function sample()
 local h=require('luci.http');if h.getenv('REQUEST_METHOD')~='GET'then h.status(405,'Method Not Allowed');return end
 editor();h.header('Cache-Control','no-store');local started=false
 local result=require('schoolbell.media_web').sample(h.formvalue('id',true) or 'test',function(chunk)
  if not started then h.prepare_content('audio/mpeg');started=true end;h.write(chunk)
 end)
 if not result.ok and not started then h.status(503,'Media unavailable')end
end
function play()
    local h=require("luci.http")
    if not require("luci.dispatcher").test_post_security() then return end
    local id=h.formvalue('id') or 'test'
    if type(id)~='string' or not require('schoolbell.media_ids').valid(id) then respond({ok=false,state='invalid'});return end
    editor();local m=require("schoolbell.sound_test")
    audit('play_requested')
    local ok,result=pcall(function()return m.run(m.system(id))end)
    if not ok then result={ok=false,state="recovery_required"} end
    h.header("Cache-Control","no-store")
    h.prepare_content("application/json")
    audit(result.ok and 'play_ok' or 'play_failed',result)
    h.write_json(result)
end

function backup()
 local h=require('luci.http');local method=h.getenv('REQUEST_METHOD')
 if method~='GET' and method~='POST'then h.status(405,'Method Not Allowed');return end
 if method=='POST'then
  local token=(h.getenv('HTTP_AUTHORIZATION') or ''):match('^Bearer ([^%s]+)$');local expected=require('luci.dispatcher').context.authtoken
  if type(token)~='string' or token=='' or token~=expected then h.status(403,'Forbidden');return end
  local size=tonumber(h.getenv('CONTENT_LENGTH'))
  if not size or size<0 or size%1~=0 or size>2162816 or h.getenv('CONTENT_TYPE')~='application/octet-stream'then h.status(413,'Unsupported request');return end
  local action=h.formvalue('action',true);local op=h.formvalue('operation',true)
  editor();if not require('schoolbell.media_codec').hex(op,32) or (action~='restore' and action~='resume') or (action=='resume' and size~=0) or (action=='restore' and size==0)then h.status(400,'Invalid request');return end
  local m=require('schoolbell.backup_web');local result
  if action=='resume'then result=m.resume(op)else result=m.restore(op,h.source(),size)end
  audit(result.ok and 'restore_ok' or 'restore_failed',result);respond(result);return
 end
 editor();local m=require('schoolbell.backup_web');local action=h.formvalue('action',true)
 if action=='status'then respond(m.status());return end
 if action~='download'then h.status(400,'Invalid request');return end
 local started=false;h.header('Cache-Control','no-store')
 local result=m.export(function(chunk)
  if not started then h.header('Content-Disposition','attachment; filename="schoolbell-backup.sbb"');h.prepare_content('application/octet-stream');started=true end
  h.write(chunk)
 end)
 if not result.ok and not started then h.status(409,'Backup unavailable');respond(result)end
end

-- Dedicated actions inherit the administrator route; Bearer carries LuCI CSRF token.
function plan_import()
 local h,d=require('luci.http'),require('luci.dispatcher')
 local action=h.formvalue('action',true);local id=h.formvalue('operation_id',true)
 local method=h.getenv('REQUEST_METHOD');editor()
 local C=require('schoolbell.media_codec')
 if not C.hex(id,32)then h.status(400,'Invalid operation');return end
 if method=='GET'then
  if action~='status'then h.status(405,'Method Not Allowed');return end
  respond(require('schoolbell.plan_import_web').request(action,id));return
 end
 if method~='POST'then h.status(405,'Method Not Allowed');return end
 local token=(h.getenv('HTTP_AUTHORIZATION')or''):match('^Bearer ([^%s]+)$')
 if not token or token==''or token~=d.context.authtoken then h.status(403,'Forbidden');return end
 local size=tonumber(h.getenv('CONTENT_LENGTH'));local content=h.getenv('CONTENT_TYPE')or''
 local allowed={upload=true,preview=true,commit=true,cancel=true,resume=true}
 if not allowed[action]then h.status(400,'Invalid action');return end
 if not size or size%1~=0 or size<1 or size>(action=='upload'and 2134098 or 8192)then h.status(413,'Too large');return end
 local args,pump
 if action=='upload'then
  if not content:match('^multipart/form%-data;')then h.status(400,'Multipart required');return end
  pump=function(emit)
   local seen,finished=false,false
   h.setfilehandler(function(meta,chunk,eof)
    assert(meta and meta.name=='file'and not finished,'format')
    seen=true;if chunk then for at=1,#chunk,16384 do emit(chunk:sub(at,at+16383))end end
    if eof then finished=true end
   end)
   h.formvalue('file');assert(seen and finished,'format')
  end
 else
  if content~='application/json'then h.status(400,'JSON required');return end
  local text=h.content();local ok,v=pcall(C.decode,text)
  if not ok or type(v)~='table'or v.operation_id~=id then h.status(400,'Invalid request');return end
  local expected=action=='preview'and {'operation_id','names'}or action=='commit'and {'operation_id','preview_token'}or {'operation_id'}
  if not pcall(C.fields,v,expected)then h.status(400,'Invalid fields');return end
  args=v
 end
 local value=require('schoolbell.plan_import_web').request(action,id,args,pump,size)
 if not value.ok then
  local code=value.code;local status=({busy=409,conflict=409,invalid_state=409,size=413,format=400,storage_unavailable=503,recovery_required=503})[code]or 422
  h.status(status,'Import not completed')
 end
 respond(value)
end

function plan_export()
 local h,d=require('luci.http'),require('luci.dispatcher')
 if h.getenv('REQUEST_METHOD')~='POST'then h.status(405,'Method Not Allowed');return end
 local token=(h.getenv('HTTP_AUTHORIZATION')or''):match('^Bearer ([^%s]+)$')
 if not token or token==''or token~=d.context.authtoken then h.status(403,'Forbidden');return end
 local size=tonumber(h.getenv('CONTENT_LENGTH'))
 if not size or size%1~=0 or size<1 or size>4096 then h.status(413,'Too large');return end
 if h.getenv('CONTENT_TYPE')~='application/json'then h.status(400,'JSON required');return end
 editor();local C=require('schoolbell.media_codec');local ok,v=pcall(function()
  local v=C.decode(h.content());C.fields(v,{'selected','revision'})
  assert(C.hex(v.revision,64)and require('modbus.json_strict').kind(v.selected)=='array'and #v.selected>=1 and #v.selected<=8)
  for _,id in ipairs(v.selected)do assert(type(id)=='string'and #id<=96)end;return v
 end)
 if not ok then h.status(400,'Invalid request');return end
 local started=false
 local result=require('schoolbell.plan_export_web').download(v.selected,v.revision,function(meta)
  h.header('Content-Disposition','attachment; filename="schoolbell-plans.sbp"');h.header('Content-Length',tostring(meta.size));h.header('Cache-Control','no-store');h.prepare_content('application/octet-stream');started=true
 end,function(chunk)h.write(chunk)end)
 if not result.ok and not started then h.status(409,'Export unavailable');respond(result)end
end
