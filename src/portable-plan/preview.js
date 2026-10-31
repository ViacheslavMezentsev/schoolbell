/* Pure preview: snapshots in, proposal out. No storage, clock, token or activation. */
'use strict';
(function(root){
 const node=typeof module!=='undefined'&&module.exports;
 const Codec=node?require('./codec.js'):root.SchoolbellPlanCodec;
 const Ranges=node?require('../../ui/root/www/schoolbell-test/ranges.js'):root.RangePlans;
 const enc=new TextEncoder();
 const clone=x=>JSON.parse(JSON.stringify(x));
 function canonical(x){if(typeof x==='string')return '"'+x.replace(/[\x00-\x1f\\"]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'))+'"';if(Array.isArray(x))return '['+x.map(canonical).join(',')+']';if(x&&typeof x==='object')return '{'+Object.keys(x).sort().map(k=>canonical(k)+':'+canonical(x[k])).join(',')+'}';return JSON.stringify(x);}
 const fields=(v,k)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===k.length&&k.every(x=>Object.hasOwnProperty.call(v,x));
 const id=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,64}$/.test(v);
 const title=v=>typeof v==='string'&&enc.encode(v).length>=1&&enc.encode(v).length<=96&&!/[\x00-\x1f\x7f]/.test(v)&&/[^ \t\r\n\v\f]/.test(v);
 const slot=v=>typeof v==='string'&&v.length<=64&&(['test','0','1','2','3','4'].includes(v)||/^user(?:[1-9][0-9]*|_[0-9a-f]+)$/.test(v));
 function preview(manifestRaw,calendarRaw,input){
  const blockers=[];let truncated=false;
  const add=(code,path)=>{if(blockers.length<64)blockers.push({code,path});else truncated=true;};
  const fail=(code,path)=>({ok:false,admitted:false,blockers:[{code,path}],blockers_truncated:false});
  const result=()=>({ok:false,admitted:false,blockers,blockers_truncated:truncated});
  let m,c,ctx;
  try{m=Codec.manifest(manifestRaw).manifest;c=Codec.parseJSON(calendarRaw,12288);ctx=clone(input);}catch(_){return fail('format','archive');}
  if(!fields(ctx,['draft','timezone','media','operation_id','automatic_enabled','dirty','target','names'])||!fields(ctx.timezone,['name','posix'])||typeof ctx.timezone.name!=='string'||typeof ctx.timezone.posix!=='string'||typeof ctx.operation_id!=='string'||!/^[0-9a-f]{32}$/.test(ctx.operation_id)||typeof ctx.automatic_enabled!=='boolean'||typeof ctx.dirty!=='boolean'||!['device','pages'].includes(ctx.target)||!Array.isArray(ctx.media)||!fields(ctx.names,['plans','schedules']))return fail('format','context');
  for(const k of ['plans','schedules'])if(!ctx.names[k]||typeof ctx.names[k]!=='object'||Array.isArray(ctx.names[k]))return fail('format','names');
  if(enc.encode(canonical(ctx.names)).length>4096)return fail('size','names');
  try{Ranges.validateDraft(ctx.draft,false);if(enc.encode(canonical(ctx.draft)).length>12288)throw Error();}catch(_){return fail('format','draft');}
  const inventory=new Map();for(const v of ctx.media){if(!fields(v,['id','size_bytes','sha256'])||!slot(v.id)||inventory.has(v.id)||!Number.isInteger(v.size_bytes)||v.size_bytes<1||v.size_bytes>524288||typeof v.sha256!=='string'||!/^[0-9a-f]{64}$/.test(v.sha256))return fail('format','inventory');inventory.set(v.id,v);}
  if(!fields(c,['plans','schedules','pre_minutes','pre_media'])||!Array.isArray(c.plans)||c.plans.length<1||c.plans.length>8||!Array.isArray(c.schedules)||c.schedules.length>16)return fail('format','calendar');
  const media=new Map(m.media.map(x=>[x.id,x])),used=new Set(),scIds=new Set(),needed=new Set(),planIds=new Set();let user=0;const temporary=new Map();
  for(const v of m.media){const t=v.source==='bundled'?v.bundled_id:'user'+(++user);temporary.set(v.id,t);}
  const ref=(key,path)=>{if(!media.has(key))add('dependency',path);else used.add(key);};
  ref(c.pre_media,'pre_media');
  for(let i=0;i<c.schedules.length;i++){const s=c.schedules[i];if(!fields(s,['id','name','color','rows'])||!id(s.id)||scIds.has(s.id)||!title(s.name)||!Number.isInteger(s.color)||s.color<1||s.color>16||!Array.isArray(s.rows))return fail('format','schedules');scIds.add(s.id);
   for(let j=0;j<s.rows.length;j++){const row=s.rows[j];if(!fields(row,['id','time','media','enabled','pre']))return fail('format','rows');ref(row.media,'schedules.'+(i+1)+'.rows.'+(j+1)+'.media');}}
  for(const p of c.plans){if(!fields(p,['id','name','start','end','schedule_ids','days'])||!id(p.id)||planIds.has(p.id)||!Array.isArray(p.schedule_ids))return fail('format','plans');planIds.add(p.id);for(const key of p.schedule_ids){if(!scIds.has(key))add('dependency','plans.schedule_ids');else needed.add(key);}}
  for(const s of c.schedules)if(!needed.has(s.id))add('dependency','schedules.'+s.id);
  for(const v of m.media)if(!used.has(v.id))add('dependency','media.'+v.id);
  if(blockers.length)return result();
  const validation=clone(c);validation.pre_media=temporary.get(c.pre_media);for(const s of validation.schedules)for(const row of s.rows)row.media=temporary.get(row.media);
  try{Ranges.validateDraft(validation,false);}catch(_){return fail('format','calendar');}
  for(const [kind,ids] of [['plans',planIds],['schedules',scIds]])for(const [key,value] of Object.entries(ctx.names[kind]))if(!ids.has(key)||!title(value))return fail('format','names.'+kind);
  if(ctx.dirty)add('dirty','draft');if(ctx.automatic_enabled)add('automatic_enabled','automatic');
  if(m.timezone.name!==ctx.timezone.name||m.timezone.posix!==ctx.timezone.posix)add('timezone','timezone');
  const currentPlans=Ranges.migrate(ctx.draft.plans||[]);
  for(const p of c.plans)for(const old of currentPlans)if(p.start<=old.end&&p.end>=old.start)add('overlap','plans.'+p.id);
  const mapping={plans:[],schedules:[],media:[],rows:[]},mediaMap=new Map(),scheduleMap=new Map();
  const reserved=new Set();for(const s of ctx.draft.schedules)for(const row of s.rows)if(/^user(?:[1-9][0-9]*|_[0-9a-f]+)$/.test(row.media))reserved.add(row.media);
  for(const key of ['pre_media','manual_media'])if(/^user(?:[1-9][0-9]*|_[0-9a-f]+)$/.test(ctx.draft[key]))reserved.add(ctx.draft[key]);
  const free=[];for(let i=1;free.length<user;i++){const id='user'+i;if(!inventory.has(id)&&!reserved.has(id))free.push(id);}let next=0;
  for(const v of m.media){let target;
   if(v.source==='bundled'){target=v.bundled_id;const have=inventory.get(target);if(!have||have.sha256!==v.sha256||have.size_bytes!==v.size_bytes)add('dependency','media.'+v.id);}
   else {if(ctx.target==='pages')add('unsupported_media','media.'+v.id);target=free[next++];if(!target)add('slots','media.'+v.id);}
   if(target){mediaMap.set(v.id,target);mapping.media.push({old_id:v.id,slot:target,title:v.title});}}
  const names={plans:new Set(currentPlans.map(x=>x.name)),schedules:new Set(ctx.draft.schedules.map(x=>x.name))};
  const oldIds={plans:new Set(currentPlans.map(x=>x.id)),schedules:new Set(ctx.draft.schedules.map(x=>x.id))};
  for(const kind of ['plans','schedules'])c[kind].forEach((v,i)=>{const name=Object.prototype.hasOwnProperty.call(ctx.names[kind],v.id)?ctx.names[kind][v.id]:v.name;const new_id='imp-'+ctx.operation_id+'-'+(kind==='plans'?'p':'s')+(i+1);
   if(names[kind].has(name))add('name_conflict',kind+'.'+v.id);names[kind].add(name);if(oldIds[kind].has(new_id))add('conflict',kind+'.'+v.id);mapping[kind].push({old_id:v.id,new_id,name});if(kind==='schedules')scheduleMap.set(v.id,new_id);});
  const preUsed=ctx.draft.schedules.some(s=>s.rows.some(row=>row.pre));const before=inventory.get(ctx.draft.pre_media),after=media.get(c.pre_media);
  if(preUsed&&(!before||before.sha256!==after.sha256||before.size_bytes!==after.size_bytes||ctx.draft.pre_minutes!==c.pre_minutes))add('pre_conflict','pre_media');
  if(blockers.length)return result();
  const candidate=clone(ctx.draft);candidate.plans=clone(ctx.draft.plans||[]);
  c.schedules.forEach((s,i)=>{const v=clone(s);v.id=mapping.schedules[i].new_id;v.name=mapping.schedules[i].name;v.rows.forEach((row,j)=>{const old=row.id;row.id='imp-'+ctx.operation_id+'-r'+(j+1);row.media=mediaMap.get(row.media);mapping.rows.push({schedule_id:s.id,old_id:old,new_id:row.id});});candidate.schedules.push(v);});
  c.plans.forEach((p,i)=>{const v=clone(p);v.id=mapping.plans[i].new_id;v.name=mapping.plans[i].name;v.schedule_ids=v.schedule_ids.map(x=>scheduleMap.get(x));candidate.plans.push(v);});
  if(!preUsed){candidate.pre_minutes=c.pre_minutes;candidate.pre_media=mediaMap.get(c.pre_media);}
  try{Ranges.validateDraft(candidate,false);}catch(_){return fail('size','candidate');}
  const bytes=enc.encode(canonical(candidate)).length;if(bytes>12288)return fail('size','candidate');
  return {ok:true,admitted:false,blockers:[],blockers_truncated:false,candidate,mapping,candidate_bytes:bytes,pre_change:{before:{minutes:ctx.draft.pre_minutes,media:ctx.draft.pre_media},after:{minutes:candidate.pre_minutes,media:candidate.pre_media}},user_slots:next};
 }
 const api={preview};if(node)module.exports=api;else root.SchoolbellPlanPreview=api;
})(typeof globalThis!=='undefined'?globalThis:this);
