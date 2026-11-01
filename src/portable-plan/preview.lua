-- Pure preview only. No storage/clock/token/activation; snapshots are copied.
local J=require('modbus.json_strict');local C=require('schoolbell.media_codec')
local Store=require('schoolbell.schedule_store')
local found,Codec=pcall(require,'schoolbell.plan_codec');if not found then Codec=dofile('src/portable-plan/codec.lua')end
local M={}
local function arr()return assert(J.decode('[]'))end
local function clone(x)return assert(J.decode(C.encode(x)))end
local function fields(v,keys)
 if J.kind(v)~='object'then return false end
 local allowed={};for _,k in ipairs(keys)do if v[k]==nil then return false end;allowed[k]=true end
 for k in pairs(v)do if not allowed[k]then return false end end;return true
end
local function id(v)return type(v)=='string'and #v>0 and #v<=64 and v:match('^[A-Za-z0-9_-]+$')end
local function title(v)return type(v)=='string'and #v>0 and #v<=96 and not v:find('[%z\1-\31\127]')and v:find('%S')end
local function slot(v)return v=='test'or v=='0'or v=='1'or v=='2'or v=='3'or v=='4'or(type(v)=='string'and require('schoolbell.media_ids').user(v))end
local function fail(code,path)return {ok=false,admitted=false,blockers={{code=code,path=path}},blockers_truncated=false}end
local function list(v,n)return J.kind(v)=='array'and (not n or #v<=n) end
local function preview(manifest_raw,calendar_raw,input)
 local good,m=pcall(Codec.manifest,manifest_raw);local c=J.decode(calendar_raw,{bytes=12288})
 local ok,ctx=pcall(clone,input);if not good or not c or not ok then return fail('format','archive')end
 local blockers=arr();local truncated=false
 local function add(code,path)if #blockers<64 then blockers[#blockers+1]={code=code,path=path}else truncated=true end end
 local function result()return {ok=false,admitted=false,blockers=blockers,blockers_truncated=truncated}end
 if not fields(ctx,{'draft','timezone','media','operation_id','automatic_enabled','dirty','target','names'})or not fields(ctx.timezone,{'name','posix'})or type(ctx.timezone.name)~='string'or type(ctx.timezone.posix)~='string'or not C.hex(ctx.operation_id,32)or type(ctx.automatic_enabled)~='boolean'or type(ctx.dirty)~='boolean'or(ctx.target~='device'and ctx.target~='pages')or not list(ctx.media)or not fields(ctx.names,{'plans','schedules'})then return fail('format','context')end
 for _,k in ipairs({'plans','schedules'})do if J.kind(ctx.names[k])~='object'then return fail('format','names')end end
 if #C.encode(ctx.names)>4096 then return fail('size','names')end
 if not Store.validate(C.encode(ctx.draft))then return fail('format','draft')end
 local inventory={};for _,v in ipairs(ctx.media)do if not fields(v,{'id','size_bytes','sha256'})or not slot(v.id)or inventory[v.id]or not C.integer(v.size_bytes,1,524288)or not C.hex(v.sha256,64)then return fail('format','inventory')end;inventory[v.id]=v end
 if not fields(c,{'plans','schedules','pre_minutes','pre_media'})or not list(c.plans,8)or #c.plans<1 or not list(c.schedules,16)then return fail('format','calendar')end
 local media,used,scids,needed,planids,temp={},{},{},{},{},{};local users=0
 for _,v in ipairs(m.media)do if v.source=='user'and v.size_bytes>65536 then add('size','media.'..v.id)end;media[v.id]=v;if v.source=='bundled'then temp[v.id]=v.bundled_id else users=users+1;temp[v.id]='user'..users end end
 local function ref(key,path)if type(key)~='string'or not media[key]then add('dependency',path)else used[key]=true end end
 ref(c.pre_media,'pre_media')
 for i,s in ipairs(c.schedules)do if not fields(s,{'id','name','color','rows'})or not id(s.id)or scids[s.id]or not title(s.name)or not C.integer(s.color,1,16)or not list(s.rows)then return fail('format','schedules')end;scids[s.id]=true
  for j,row in ipairs(s.rows)do if not fields(row,{'id','time','media','enabled','pre'})then return fail('format','rows')end;ref(row.media,'schedules.'..i..'.rows.'..j..'.media')end end
 for _,p in ipairs(c.plans)do if not fields(p,{'id','name','start','end','schedule_ids','days'})or not id(p.id)or planids[p.id]or not list(p.schedule_ids,16)then return fail('format','plans')end;planids[p.id]=true
  for _,key in ipairs(p.schedule_ids)do if type(key)~='string'or not scids[key]then add('dependency','plans.schedule_ids')else needed[key]=true end end end
 for _,s in ipairs(c.schedules)do if not needed[s.id]then add('dependency','schedules.'..s.id)end end
 for _,v in ipairs(m.media)do if not used[v.id]then add('dependency','media.'..v.id)end end
 if #blockers>0 then return result()end
 local validation=clone(c);validation.pre_media=temp[c.pre_media]
 for _,s in ipairs(validation.schedules)do for _,row in ipairs(s.rows)do row.media=temp[row.media]end end
 if not Store.validate(C.encode(validation))then return fail('format','calendar')end
 for _,kind in ipairs({'plans','schedules'})do local ids=kind=='plans'and planids or scids
  for key,value in pairs(ctx.names[kind])do if not ids[key]or not title(value)then return fail('format','names.'..kind)end end end
 if ctx.dirty then add('dirty','draft')end;if ctx.automatic_enabled then add('automatic_enabled','automatic')end
 if m.timezone.name~=ctx.timezone.name or m.timezone.posix~=ctx.timezone.posix then add('timezone','timezone')end
 local current=clone(ctx.draft.plans or arr())
 for i,p in ipairs(current)do if p.year then current[i]={id='year-'..p.year,name='План '..p.year,start=string.format('%04d-01-01',p.year),['end']=string.format('%04d-12-31',p.year),schedule_ids=p.schedule_ids,days=p.days}end end
 for _,p in ipairs(c.plans)do for _,old in ipairs(current)do if p.start<=old['end']and p['end']>=old.start then add('overlap','plans.'..p.id)end end end
 local mapping={plans=arr(),schedules=arr(),media=arr(),rows=arr()};local mediamap,schedulemap,reserved={},{},{}
 for _,s in ipairs(ctx.draft.schedules)do for _,row in ipairs(s.rows)do if require('schoolbell.media_ids').user(row.media)then reserved[row.media]=true end end end
 for _,key in ipairs({'pre_media','manual_media'})do local v=ctx.draft[key];if v and require('schoolbell.media_ids').user(v)then reserved[v]=true end end
 local free={};local i=0;while #free<users do i=i+1;local key='user'..i;if not inventory[key]and not reserved[key]then free[#free+1]=key end end;local nextslot=0
 for _,v in ipairs(m.media)do local target
  if v.source=='bundled'then target=v.bundled_id;local have=inventory[target];if not have or have.sha256~=v.sha256 or have.size_bytes~=v.size_bytes then add('dependency','media.'..v.id)end
  else if ctx.target=='pages'then add('unsupported_media','media.'..v.id)end;nextslot=nextslot+1;target=free[nextslot];if not target then add('slots','media.'..v.id)end end
  if target then mediamap[v.id]=target;mapping.media[#mapping.media+1]={old_id=v.id,slot=target,title=v.title}end end
 local names={plans={},schedules={}};local oldids={plans={},schedules={}}
 for _,p in ipairs(current)do names.plans[p.name]=true;oldids.plans[p.id]=true end
 for _,s in ipairs(ctx.draft.schedules)do names.schedules[s.name]=true;oldids.schedules[s.id]=true end
 for _,kind in ipairs({'plans','schedules'})do for i,v in ipairs(c[kind])do
  local name=ctx.names[kind][v.id]or v.name;local new='imp-'..ctx.operation_id..'-'..(kind=='plans'and'p'or's')..i
  if names[kind][name]then add('name_conflict',kind..'.'..v.id)end;names[kind][name]=true;if oldids[kind][new]then add('conflict',kind..'.'..v.id)end
  mapping[kind][#mapping[kind]+1]={old_id=v.id,new_id=new,name=name};if kind=='schedules'then schedulemap[v.id]=new end end end
 local preused=false;for _,s in ipairs(ctx.draft.schedules)do for _,row in ipairs(s.rows)do if row.pre then preused=true end end end
 local before,after=inventory[ctx.draft.pre_media],media[c.pre_media]
 if preused and(not before or before.sha256~=after.sha256 or before.size_bytes~=after.size_bytes or ctx.draft.pre_minutes~=c.pre_minutes)then add('pre_conflict','pre_media')end
 if #blockers>0 then return result()end
 local candidate=clone(ctx.draft);candidate.plans=candidate.plans or arr()
 for i,s in ipairs(c.schedules)do local v=clone(s);v.id=mapping.schedules[i].new_id;v.name=mapping.schedules[i].name
  for j,row in ipairs(v.rows)do local old=row.id;row.id='imp-'..ctx.operation_id..'-r'..j;row.media=mediamap[row.media];mapping.rows[#mapping.rows+1]={schedule_id=s.id,old_id=old,new_id=row.id}end
  candidate.schedules[#candidate.schedules+1]=v end
 for i,p in ipairs(c.plans)do local v=clone(p);v.id=mapping.plans[i].new_id;v.name=mapping.plans[i].name;for j,key in ipairs(v.schedule_ids)do v.schedule_ids[j]=schedulemap[key]end;candidate.plans[#candidate.plans+1]=v end
 if not preused then candidate.pre_minutes=c.pre_minutes;candidate.pre_media=mediamap[c.pre_media]end
 local encoded=C.encode(candidate);if not Store.validate(encoded)then return fail('size','candidate')end
 return {ok=true,admitted=false,blockers=arr(),blockers_truncated=false,candidate=candidate,mapping=mapping,candidate_bytes=#encoded,pre_change={before={minutes=ctx.draft.pre_minutes,media=ctx.draft.pre_media},after={minutes=candidate.pre_minutes,media=candidate.pre_media}},user_slots=nextslot}
end
function M.preview(...)
 local ok,result=pcall(preview,...)
 return ok and result or fail('format','input')
end
return M
