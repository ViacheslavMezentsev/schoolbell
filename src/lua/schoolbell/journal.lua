-- Bounded package audit log, independent of the core journal and scheduler.
local C=require('schoolbell.media_codec')
local J=require('modbus.json_strict')
local M={segment_bytes=16384,record_bytes=320}
local names={'journal-previous.jsonl','journal-current.jsonl'}
local actions={system_reset={'user','warning'},system_reboot={'user','warning'},system_failed={'system','error'},clock_set_ok={'user','warning'},clock_set_failed={'system','error'},clock_confirmed={'user','info'},clock_control_on={'user','info'},clock_control_off={'user','warning'},clock_control_failed={'system','error'},restore_ok={'user','info'},restore_failed={'user','error'},media_ok={'user','info'},media_renamed={'user','info'},media_failed={'user','error'},volume_ok={'user','info'},volume_failed={'system','error'},auto_enabled={'user','info'},auto_disabled={'user','info'},auto_requested={'module','info'},auto_ok={'module','info'},auto_skipped={'module','warning'},auto_blocked={'system','error'},mute_on={"user","info"},mute_off={"user","info"},mute_failed={"system","error"},manual_requested={"user","info"},timezone_ok={'user','info'},timezone_failed={'system','error'},save_ok={'user','info'},save_failed={'user','error'},preview_ok={'user','info'},
 preview_failed={'user','warning'},play_requested={'user','info'},play_ok={'module','info'},
 play_failed={'module','error'},sample_requested={'user','info'},storage_error={'system','error'},
 installed={'module','info'}}
local function entries(fs)
 local out=assert(J.decode('[]'));local last=0
 for _,name in ipairs(names)do
  local raw=fs.read(name,M.segment_bytes) or ''
  assert(raw=='' or raw:sub(-1)=='\n','incomplete journal')
  for line in raw:gmatch('([^\n]+)\n')do
   assert(#line+1<=M.record_bytes,'record size')
   local row=assert(C.decode(line));local a=actions[row.action]
   assert(a and C.integer(row.seq,1,2147483647) and row.seq>last and C.integer(row.time,0,4102444800)
    and row.source==a[1] and row.level==a[2],'record')
   last=row.seq;out[#out+1]=row
  end
 end
 return out,last
end
-- Timestamps describe events; only byte limits evict records (TC-166).
function M.read(fs,now)
 return entries(fs)
end
function M.append(fs,action,now)
 local a=assert(actions[action],'action');assert(C.integer(now,0,4102444800),'time')
 local rows,last=entries(fs);assert(last<2147483647,'sequence exhausted')
 local line=C.encode({seq=last+1,time=now,source=a[1],level=a[2],action=action})..'\n'
 assert(#line<=M.record_bytes,'record size')
 local current=fs.read(names[2],M.segment_bytes) or ''
 -- An interrupted temp is uncommitted; only fixed private filenames are touched.
 if fs.stat('journal-next.tmp')then fs.unlink('journal-next.tmp')end
 assert(fs.space()>=65536+M.segment_bytes,'space reserve')
 local rotate=#current+#line>M.segment_bytes
 fs.write('journal-next.tmp',(rotate and '' or current)..line);fs.sync('journal-next.tmp')
 if rotate then fs.rename(names[2],names[1]);fs.sync('')end
 fs.rename('journal-next.tmp',names[2]);fs.sync('')
 return true
end
function M.request(root,action,host)
 local ok,fs=pcall(require('schoolbell.media_fs').new,root,host)
 if not ok then return {ok=false,code='journal_unavailable'}end
 local success,value=pcall(function()
  if action then M.append(fs,action,os.time());return {ok=true}end
  local rows=M.read(fs,os.time())
  for _,row in ipairs(rows)do row.local_time=os.date('%d.%m.%Y %H:%M:%S %z',row.time) end
  return {ok=true,entries=rows,limit_bytes=2*M.segment_bytes,peak_bytes=3*M.segment_bytes}
 end)
 local closed=pcall(fs.close)
 if not success or not closed then return {ok=false,code='journal_unavailable'}end
 return value
end
return M
