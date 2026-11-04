-- Bounded package audit log, independent of the core journal and scheduler.
local C=require('schoolbell.media_codec')
local J=require('modbus.json_strict')
local M={segment_bytes=16384,record_bytes=320}
local banks={{'journal-previous.jsonl','journal-current.jsonl'},{'journal-alt-previous.jsonl','journal-alt-current.jsonl'}}
local settings='journal-limit.json'
local function valid(k)return k==16 or k==32 or k==64 or k==128 end
function M.layout(fs)
 local raw=fs.read(settings,128)
 if not raw then return banks[1],M.segment_bytes end
 local cfg=C.decode(raw)
 assert(valid(cfg.kib) and (cfg.bank==1 or cfg.bank==2),'journal limit')
 return banks[cfg.bank],cfg.kib*512
end
local actions={device_boot={'system','info'},auto_audio_unavailable={'module','error'},auto_player_failed={'module','error'},auto_expired={'module','warning'},system_reset={'user','warning'},system_reboot={'user','warning'},system_failed={'system','error'},clock_set_ok={'user','warning'},clock_set_failed={'system','error'},clock_confirmed={'user','info'},clock_control_on={'user','info'},clock_control_off={'user','warning'},clock_control_failed={'system','error'},restore_ok={'user','info'},restore_failed={'user','error'},media_ok={'user','info'},media_renamed={'user','info'},media_failed={'user','error'},volume_ok={'user','info'},volume_failed={'system','error'},draft_applied={'user','info'},auto_enabled={'user','info'},auto_disabled={'user','info'},auto_requested={'module','info'},auto_ok={'module','info'},auto_skipped={'module','warning'},auto_blocked={'system','error'},mute_on={"user","info"},mute_off={"user","info"},mute_failed={"system","error"},manual_requested={"user","info"},timezone_ok={'user','info'},timezone_failed={'system','error'},save_ok={'user','info'},save_failed={'user','error'},preview_ok={'user','info'},
 preview_failed={'user','warning'},play_requested={'user','info'},play_ok={'module','info'},
 play_failed={'module','error'},sample_requested={'user','info'},storage_error={'system','error'},
 installed={'module','info'}}
local function entries(fs,names,segment)
 local out=assert(J.decode('[]'));local last=0
 for _,name in ipairs(names)do
  local raw=fs.read(name,segment) or ''
  assert(raw=='' or raw:sub(-1)=='\n','incomplete journal')
  for line in raw:gmatch('([^\n]+)\n')do
   assert(#line+1<=M.record_bytes,'record size')
   local row=assert(C.decode(line));local a=actions[row.action]
   if row.cleared==true then
    assert(C.integer(row.seq,1,2147483647) and row.seq>=last,'clear boundary')
    out=assert(J.decode('[]'));last=row.seq
   else
   assert(a and C.integer(row.seq,1,2147483647) and row.seq>last and C.integer(row.time,0,4102444800)
    and row.source==a[1] and row.level==a[2],'record')
   last=row.seq;out[#out+1]=row
   end
  end
 end
 return out,last
end
-- Timestamps describe events; only byte limits evict records (TC-166).
function M.read(fs,now)
 return entries(fs,M.layout(fs))
end
function M.append(fs,action,now,boot,bell)
 local a=assert(actions[action],'action');assert(C.integer(now,0,4102444800),'time')
 local names,segment=M.layout(fs)
 local rows,last=entries(fs,names,segment);assert(last<2147483647,'sequence exhausted')
 local row={seq=last+1,time=now,source=a[1],level=a[2],action=action}
 if action=='device_boot' then row.boot=assert(boot) end
 if bell then
  row.bell={kind=bell.kind,due=bell.due,plan=bell.plan,schedule=bell.schedule}
  row.local_time=os.date('%d.%m.%Y %H:%M:%S %z',now)
 end
 local line=C.encode(row)..'\n'
 -- Preserve times and kind even when both user-defined names reach the maximum.
 while bell and #line>M.record_bytes do
  local key=#(row.bell.plan or '')>#(row.bell.schedule or '') and 'plan' or 'schedule'
  local name=assert(row.bell[key])
  if name:sub(-3)=='…' then name=name:sub(1,-4) end
  local shorter=name:gsub('[%z\1-\127\194-\244][\128-\191]*$','')
  assert(#shorter<#name,'record size')
  row.bell[key]=shorter..'…'
  line=C.encode(row)..'\n'
 end
 assert(#line<=M.record_bytes,'record size')
 local current=fs.read(names[2],segment) or ''
 -- An interrupted temp is uncommitted; only fixed private filenames are touched.
 if fs.stat('journal-next.tmp')then fs.unlink('journal-next.tmp')end
 assert(fs.space()>=65536+segment,'space reserve')
 local rotate=#current+#line>segment
 fs.write('journal-next.tmp',(rotate and '' or current)..line);fs.sync('journal-next.tmp')
 if rotate then
  -- Commit counts before any journal segment can be evicted. On failure retain evidence.
  require('schoolbell.bell_metrics').sync(fs,rows)
  fs.rename(names[2],names[1]);fs.sync('')
 end
 fs.rename('journal-next.tmp',names[2]);fs.sync('')
 rows[#rows+1]=row
 return true,rows
end
-- A persistent marker also survives eviction of the boot event from the bounded log.
-- If interrupted between journal and marker publication, find the committed event.
function M.record_boot(fs,boot,at)
 assert(type(boot)=='string' and #boot>0 and #boot<=64)
 local marker='journal-boot'
 if fs.read(marker,64)==boot then return true end
 local found=false
 for _,entry in ipairs((M.read(fs))) do
  if entry.action=='device_boot' and entry.boot==boot then found=true;break end
 end
 if not found then M.append(fs,'device_boot',at,boot) end
 local tmp='journal-boot.next'
 if fs.stat(tmp) then fs.unlink(tmp) end
 fs.write(tmp,boot);fs.sync(tmp);fs.rename(tmp,marker);fs.sync('')
 return true
end
-- Writers replace whole segments by rename. A rotation changes the previous
-- segment first; retry if it changed while acquiring the two byte strings.
function M.snapshot(reader)
 for attempt=1,3 do
  local names,segment=M.layout(reader)
  local previous=reader.read(names[1],segment)
  local current=reader.read(names[2],segment)
  local currentNames,currentSize=M.layout(reader)
  if names==currentNames and segment==currentSize and previous==reader.read(names[1],segment) then
   local segments={[names[1]]=previous,[names[2]]=current}
   local rows,last=entries({read=function(name)return segments[name]end},names,segment)
   return rows,last,segment
  end
 end
 error('journal rotated during read')
end
-- Under the writer lock, checkpoint all bell counts before publishing the clear
-- boundary. A crash before removal of the older segment cannot resurrect it.
function M.clear(fs)
 local names,segment=M.layout(fs)
 local rows,last=entries(fs,names,segment)
 if #rows==0 then return end
 require('schoolbell.bell_metrics').sync(fs,rows)
 local tmp='journal-next.tmp'
 if fs.stat(tmp)then fs.unlink(tmp)end
 fs.write(tmp,C.encode({cleared=true,seq=last})..'\n');fs.sync(tmp)
 fs.rename(tmp,names[2]);fs.sync('')
 if fs.stat(names[1])then fs.unlink(names[1]);fs.sync('')end
end
-- Build the new pair in the inactive bank before atomically selecting it.
-- Pack backwards so a shrink retains a contiguous suffix of whole events.
function M.resize(fs,kib,expected,confirmed)
 assert(valid(kib),'journal limit')
 local old,segment=M.layout(fs)
 if expected~=segment/512 then return {ok=false,code='conflict'} end
 if kib==expected then return {ok=true,limit_bytes=kib*1024} end
 if kib<expected and not confirmed then return {ok=false,code='confirm_shrink'} end
 local rows,last=entries(fs,old,segment)
 require('schoolbell.bell_metrics').sync(fs,rows,nil,last)
 local size=kib*512
 local bank=old==banks[1] and 2 or 1
 local target=banks[bank]
 local chunks={{},{}}
 local slot,total=2,0
 for i=#rows,1,-1 do
  local line=C.encode(rows[i])..'\n'
  if total+#line>size then
   if slot==1 then break end
   slot=1;total=0
  end
  chunks[slot][#chunks[slot]+1]=line;total=total+#line
 end
 if #rows==0 and last>0 then chunks[2][1]=C.encode({cleared=true,seq=last})..'\n' end
 assert(fs.space()>=65536+math.min(kib,expected)*1024+4096,'space reserve')
 for n,path in ipairs(target)do
  if fs.stat(path)then fs.unlink(path)end
  local reverse=chunks[n];local lines={}
  for i=#reverse,1,-1 do lines[#lines+1]=reverse[i] end
  if #lines>0 then fs.write(path,table.concat(lines));fs.sync(path)end
 end
 fs.sync('')
 local tmp='journal-limit.next'
 if fs.stat(tmp)then fs.unlink(tmp)end
 fs.write(tmp,C.encode({bank=bank,kib=kib}));fs.sync(tmp)
 fs.rename(tmp,settings);fs.sync('')
 for _,path in ipairs(old)do if fs.stat(path)then fs.unlink(path)end end
 fs.sync('')
 return {ok=true,limit_bytes=kib*1024}
end
function M.request(root,action,host,bell,resize)
 local storage=require('schoolbell.media_fs')
 local ok,fs=pcall(action and action~="limit" and storage.new or storage.readonly,root,host)
 if not ok then return {ok=false,code='journal_unavailable'}end
 local success,value=pcall(function()
  if action=='limit' then local _,segment=M.layout(fs);return {ok=true,limit_bytes=2*segment} end
  if action=='resize' then return M.resize(fs,resize.kib,resize.expected,resize.confirmed) end
  if action=="clear"  then M.clear(fs);return {ok=true} end
  if action then
   local _,rows=M.append(fs,action,os.time(),nil,bell)
   -- The journal is a recovery source if aggregation is interrupted after append.
   local saved=true
   if action=='auto_ok' or action=='auto_enabled'then saved=pcall(function()require('schoolbell.bell_metrics').sync(fs,rows)end)end
   return {ok=true,metrics_warning=not saved or nil}
  end
  local rows,_,segment=M.snapshot(fs)
  for _,row in ipairs(rows)do row.local_time=row.local_time or os.date('%d.%m.%Y %H:%M:%S %z',row.time) end
  return {ok=true,entries=rows,limit_bytes=2*segment,peak_bytes=3*segment}
 end)
 local closed=pcall(fs.close)
 if not success or not closed then return {ok=false,code='journal_unavailable'}end
 return value
end
return M
