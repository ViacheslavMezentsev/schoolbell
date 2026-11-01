-- Caller owns player gate and editor lock. Melodies, journal and OS config are untouched.
local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store')
local A=require('schoolbell.automatic_store');local Controls=require('schoolbell.controls')
local M={}
function M.apply(fs,operation,checkpoint)
 assert(C.hex(operation,32),'operation');local hook=checkpoint or function()end
 local function put(name,raw)
  if fs.stat('system-next.json')then fs.unlink('system-next.json')end
  fs.write('system-next.json',raw);fs.sync('system-next.json');fs.rename('system-next.json',name);fs.sync('')
 end
 local function sealed(v)return C.encode({data=v,checksum=C.sha(C.encode(v))})end
 local raw=fs.read('restore.pending',4096);local p
 if raw then
  local v=C.decode(raw);p=v.data
  assert(type(p)=='table' and p.kind=='schoolbell-reset/1' and v.checksum==C.sha(C.encode(p)),'restore_pending')
  assert(C.hex(p.operation,32) and C.integer(p.auto,1,2147483647) and C.integer(p.control,1,2147483647) and C.integer(p.watermark,0,2147483647),'reset marker')
 else
  local auto=A.decode(fs.read(A.name,A.max_bytes));local control=Controls.decode(fs.read('sound-control.json',512))
  assert(auto.generation<2147483647 and control.generation<2147483647,'generation')
  local free,total=fs.space();assert(free>=math.max(524288,math.ceil(total/10))+65536,'space')
  p={kind='schoolbell-reset/1',operation=operation,auto=auto.generation+1,control=control.generation+1,watermark=auto.watermark}
  put('restore.pending',sealed(p));hook('pending')
 end
 put(A.name,sealed({enabled=false,generation=p.auto,watermark=p.watermark}));hook('disabled')
 put('current.json',sealed(S.empty()));hook('draft')
 put('sound-control.json',C.encode({muted=false,volume_db=0,generation=p.control}));hook('controls')
 put('clock-policy.json',C.encode({enforced=true}));hook('policy')
 for _,name in ipairs({'previous.json','import-receipts.json','restore-last.json','clock-policy.pending'})do if fs.stat(name)then fs.unlink(name)end end
 fs.sync('');hook('cleanup')
 local draft=S.load(fs);assert(draft.ok and #draft.data.schedules==0 and draft.data.mode=='fixed','draft verify')
 assert(not A.decode(fs.read(A.name,A.max_bytes)).enabled,'auto verify')
 local control=Controls.decode(fs.read('sound-control.json',512));assert(not control.muted and control.volume_db==0,'control verify')
 put('system-last.json',C.encode({operation=p.operation,state='reset'}));hook('verified')
 fs.unlink('restore.pending');fs.sync('');hook('complete')
 return {ok=true,state='reset',automatic_enabled=false}
end
return M
