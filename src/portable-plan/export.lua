-- Isolated assembly; no storage, player or clock calls. Streams are caller-owned.
local J=require('modbus.json_strict');local C=require('schoolbell.media_codec')
local Store=require('schoolbell.schedule_store');local ok,Codec=pcall(require,'schoolbell.plan_codec');if not ok then Codec=dofile('src/portable-plan/codec.lua')end
local M={}
local function need(v,c)if not v then error(c,0)end end
local function arr()return assert(J.decode('[]'))end
local function fields(v,keys)
 if J.kind(v)~='object'then return false end
 local allowed={};for _,k in ipairs(keys)do if v[k]==nil then return false end;allowed[k]=true end
 for k in pairs(v)do if not allowed[k]then return false end end;return true
end
local slots={'test','0','1','2','3','4','user1','user2','user3','user4','user5','user6','user7','user8'}
function M.prepare(input)
 local x=J.decode(C.encode(input));need(x,'format')
 need(fields(x,{'draft','selected','timezone','media','exporter'}),'format')
 need(Store.validate(C.encode(x.draft)),'format')
 need(J.kind(x.selected)=='array'and #x.selected>=1 and #x.selected<=8,'selection')
 local selected={};for _,id in ipairs(x.selected)do need(type(id)=='string'and not selected[id],'selection');selected[id]=true end
 need(J.kind(x.media)=='array','format')
 local valid=setmetatable({},{__index=function(_,id)return require('schoolbell.media_ids').valid(id)end})
 local slots={};for _,v in ipairs(x.media)do slots[#slots+1]=v.id end;local order={test=1,['0']=2,['1']=3,['2']=4,['3']=5,['4']=6};for i=1,8 do order['user'..i]=6+i end;table.sort(slots,function(a,b)if order[a]or order[b]then return (order[a]or 99)<(order[b]or 99)end;return a<b end)
 local inventory={};for _,v in ipairs(x.media)do need(fields(v,{'id','title','size_bytes','sha256'})and valid[v.id]and not inventory[v.id],'format');inventory[v.id]=v end
 local plans,wanted=arr(),{}
 for _,p in ipairs(x.draft.plans or {})do
  if p.year then local y=string.format('%04d',p.year);p={id='year-'..p.year,name='План '..p.year,start=y..'-01-01',['end']=y..'-12-31',schedule_ids=p.schedule_ids,days=p.days}end
  if selected[p.id]then plans[#plans+1]=p;for _,id in ipairs(p.schedule_ids)do wanted[id]=true end end
 end
 need(#plans==#x.selected,'selection')
 local schedules,used=arr(),{[x.draft.pre_media]=true}
 for i,s in ipairs(x.draft.schedules)do if wanted[s.id]then
  s.color=s.color or ((i-1)%16+1);schedules[#schedules+1]=s;wanted[s.id]=nil
  for _,row in ipairs(s.rows)do used[row.media]=true end
 end end
 need(next(wanted)==nil,'dependency')
 local calendar={plans=plans,schedules=schedules,pre_minutes=x.draft.pre_minutes,pre_media=x.draft.pre_media}
 local calendar_raw=C.encode(calendar);need(#calendar_raw<=12288,'size')
 local media,payloads=arr(),{}
 for _,id in ipairs(slots)do if used[id]then
  local v=inventory[id];need(v,'dependency')
  local entry={id=id,title=v.title,size_bytes=v.size_bytes,sha256=v.sha256,source=id:match('^user')and'user'or'bundled'}
  if entry.source=='bundled'then entry.bundled_id=id else
   need(x.exporter and x.exporter.name~='schoolbell-pages','unsupported_media')
   entry.file='media/'..tostring(v.sha256)..'.mp3';local old=payloads[entry.file];need(not old or old.size_bytes==v.size_bytes,'dependency')
   if not old then payloads[entry.file]={name=entry.file,slot=id,size_bytes=v.size_bytes,sha256=v.sha256}end
  end
  media[#media+1]=entry;used[id]=nil
 end end
 need(next(used)==nil,'dependency')
 local sources=arr();for _,v in pairs(payloads)do sources[#sources+1]=v end;table.sort(sources,function(a,b)return a.name<b.name end)
 local files=arr();files[1]={name='calendar.json',size_bytes=#calendar_raw,sha256=C.sha(calendar_raw)}
 for _,v in ipairs(sources)do files[#files+1]={name=v.name,size_bytes=v.size_bytes,sha256=v.sha256}end
 local users=0;for _,v in ipairs(media)do if v.source=='user'then users=users+1 end end
 local manifest={format=(users>8) and 'schoolbell-plan/2' or 'schoolbell-plan/1',exporter=x.exporter,timezone=x.timezone,files=files,media=media}
 local manifest_raw=C.encode(manifest);Codec.manifest(manifest_raw)
 return {manifest=manifest_raw,calendar=calendar_raw,sources=sources}
end
function M.encode(input,source_for,hash_factory,emit)
 local p=M.prepare(input);local sources={};for _,v in ipairs(p.sources)do sources[v.name]=v end
 return Codec.encode(p.manifest,function(name)
  if name=='calendar.json'then local done=false;return function()if done then return nil end;done=true;return p.calendar end end
  local v=sources[name];return source_for(v.slot,{name=v.name,slot=v.slot,size_bytes=v.size_bytes,sha256=v.sha256})
 end,hash_factory,emit)
end
return M
