/* Isolated export assembly. Caller supplies a coherent snapshot and pinned streams. */
'use strict';
(function(root){
 const node=typeof module!=='undefined'&&module.exports;
 const Codec=node?require('./codec.js'):root.SchoolbellPlanCodec;
 const Ranges=node?require('../../ui/root/www/schoolbell-test/ranges.js'):root.RangePlans;
 const enc=new TextEncoder();
 const need=(v,c)=>{if(!v)throw Error(c);};
 const fields=(v,ks)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===ks.length&&ks.every(k=>Object.prototype.hasOwnProperty.call(v,k));
 function canonical(x){if(typeof x==='string')return '"'+x.replace(/[\x00-\x1f\\"]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'))+'"';if(Array.isArray(x))return '['+x.map(canonical).join(',')+']';if(x&&typeof x==='object')return '{'+Object.keys(x).sort().map(k=>canonical(k)+':'+canonical(x[k])).join(',')+'}';need(typeof x==='boolean'||Number.isSafeInteger(x),'format');return JSON.stringify(x);}
 const raw=x=>enc.encode(canonical(x));
 const slots=['test','0','1','2','3','4','user1','user2','user3','user4','user5','user6','user7','user8'];
 async function prepare(input,hashFactory){
  const x=Codec.parseJSON(raw(input),16384);
  need(fields(x,['draft','selected','timezone','media','exporter']),'format');
  Ranges.validateDraft(x.draft,false);need(raw(x.draft).length<=12288,'size');
  need(Array.isArray(x.selected)&&x.selected.length>=1&&x.selected.length<=8&&x.selected.every(v=>typeof v==='string')&&new Set(x.selected).size===x.selected.length,'selection');
  need(Array.isArray(x.media),'format');
  const inventory=new Map();for(const v of x.media){need(fields(v,['id','title','size_bytes','sha256'])&&(slots.includes(v.id)||/^user(?:[1-9][0-9]*|_[0-9a-f]+)$/.test(v.id))&&!inventory.has(v.id),'format');inventory.set(v.id,v);}
  const all=Ranges.migrate(x.draft.plans||[]),selected=new Set(x.selected),plans=all.filter(p=>selected.has(p.id));need(plans.length===selected.size,'selection');
  const wanted=new Set(plans.flatMap(p=>p.schedule_ids)),used=new Set([x.draft.pre_media]),schedules=[];
  x.draft.schedules.forEach((s,i)=>{if(wanted.has(s.id)){if(s.color===undefined)s.color=i%16+1;schedules.push(s);for(const row of s.rows)used.add(row.media);}});
  need(schedules.length===wanted.size,'dependency');
  const calendar={plans,schedules,pre_minutes:x.draft.pre_minutes,pre_media:x.draft.pre_media};
  const calendarRaw=raw(calendar);need(calendarRaw.length<=12288,'size');
  const hash=hashFactory();need(await hash.update(calendarRaw)!==false,'io');const sha=await hash.finish();
  const media=[],payloads=new Map();
  for(const id of [...inventory.keys()].sort((a,b)=>{const x=slots.indexOf(a),y=slots.indexOf(b);return x>=0||y>=0?(x>=0?x:99)-(y>=0?y:99):a<b?-1:a>b?1:0;})){if(!used.has(id))continue;const v=inventory.get(id);need(v,'dependency');const entry={id,title:v.title,size_bytes:v.size_bytes,sha256:v.sha256,source:id.startsWith('user')?'user':'bundled'};
   if(entry.source==='bundled')entry.bundled_id=id;
   else {need(x.exporter&&x.exporter.name!=='schoolbell-pages','unsupported_media');entry.file='media/'+v.sha256+'.mp3';const old=payloads.get(entry.file);need(!old||old.size_bytes===v.size_bytes,'dependency');if(!old)payloads.set(entry.file,{name:entry.file,slot:id,size_bytes:v.size_bytes,sha256:v.sha256});}
   media.push(entry);
  }
  need(media.length===used.size,'dependency');
  const sources=[...payloads.values()].sort((a,b)=>a.name<b.name?-1:a.name>b.name?1:0);
  const manifest={format:media.filter(v=>v.source==='user').length>8?'schoolbell-plan/2':'schoolbell-plan/1',exporter:x.exporter,timezone:x.timezone,files:[{name:'calendar.json',size_bytes:calendarRaw.length,sha256:sha},...sources.map(({name,size_bytes,sha256})=>({name,size_bytes,sha256}))],media};
  const manifestRaw=raw(manifest);Codec.manifest(manifestRaw);
  return {manifest:manifestRaw,calendar:calendarRaw,sources};
 }
 async function encode(input,sourceFor,hashFactory,emit){
  const p=await prepare(input,hashFactory),sources=new Map(p.sources.map(v=>[v.name,v]));
  return Codec.encode(p.manifest,async name=>{if(name==='calendar.json'){let done=false;return ()=>{if(done)return null;done=true;return p.calendar;};}const v=sources.get(name);return sourceFor(v.slot,{...v});},hashFactory,emit);
 }
 const api={prepare,encode};if(node)module.exports=api;else root.SchoolbellPlanExport=api;
})(typeof globalThis!=='undefined'?globalThis:this);
