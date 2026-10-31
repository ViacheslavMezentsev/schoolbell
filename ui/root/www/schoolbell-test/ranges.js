(function(root){
'use strict';
const DAY=86400000;
function ordinal(s){if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(s))throw Error('Укажите дату');const a=s.split('-').map(Number),d=new Date(0);d.setUTCFullYear(a[0],a[1]-1,a[2]);d.setUTCHours(0,0,0,0);if(a[0]<1||d.toISOString().slice(0,10)!==s)throw Error('Некорректная дата');return d.getTime()/DAY;}
function dates(start,end){const a=ordinal(start),b=ordinal(end);if(b<a)throw Error('Окончание раньше начала');return Array.from({length:b-a+1},(_,i)=>new Date((a+i)*DAY).toISOString().slice(0,10));}
function validate(plans){if(!Array.isArray(plans)||plans.length>8)throw Error('Не более 8 планов');const ids=new Set();for(const p of plans){fields(p,['id','name','start','end','schedule_ids','days'],['id','name','start','end','schedule_ids','days']);if(typeof p.id!=='string'||!/^[A-Za-z0-9_-]{1,64}$/.test(p.id)||ids.has(p.id))throw Error('Повтор ID');ids.add(p.id);if(!title(p.name))throw Error('Название: 1–96 байт');const count=ordinal(p.end)-ordinal(p.start)+1;if(count<1)throw Error('Окончание раньше начала');if(typeof p.days!=='string'||p.days.length!==count)throw Error('Длина назначений');if(!Array.isArray(p.schedule_ids)||p.schedule_ids.some(x=>!goodId(x)||x==='quiet')||p.schedule_ids.length>16||new Set(p.schedule_ids).size!==p.schedule_ids.length)throw Error('Ссылки расписаний');for(const c of p.days)if(c!=='.'&&(c<'A'||c.charCodeAt(0)-65>=p.schedule_ids.length))throw Error('Код расписания');}
const sorted=[...plans].sort((a,b)=>a.start.localeCompare(b.start));for(let i=1;i<sorted.length;i++)if(sorted[i].start<=sorted[i-1].end)throw Error('Диапазон пересекается с «'+sorted[i-1].name+'»');return true;}
function resize(p,start,end,name){const old=dates(p.start,p.end),next=dates(start,end),map=new Map(old.map((d,i)=>[d,p.days[i]]));const keep=new Set(next);return {removed:old.filter((d,i)=>!keep.has(d)&&p.days[i]!=='.').length,plan:{...p,name,start,end,days:next.map(d=>map.get(d)||'.').join('')}};}
function migrate(plans){if(!Array.isArray(plans))throw Error('Планы');for(const p of plans)if(p.year!==undefined){fields(p,['year','schedule_ids','days'],['year','schedule_ids','days']);if(!Number.isInteger(p.year)||p.year<1||p.year>9999)throw Error('Год');}const out=plans.map(p=>p.year!==undefined?{id:'year-'+p.year,name:'План '+p.year,start:String(p.year).padStart(4,'0')+'-01-01',end:String(p.year).padStart(4,'0')+'-12-31',schedule_ids:[...p.schedule_ids],days:p.days}:JSON.parse(JSON.stringify(p)));validate(out);return out;}
// A proposal is never a saved plan; untrusted router dates must not seed it.
function suggest(today,trusted){if(!trusted)return null;ordinal(today);const y=Number(today.slice(0,4)),month=Number(today.slice(5,7)),startYear=month>=9?y:y-1;if(startYear<1||startYear>=9999)return null;return {name:'Учебный год '+startYear+'–'+(startYear+1),start:String(startYear).padStart(4,'0')+'-09-01',end:String(startYear+1).padStart(4,'0')+'-05-31'};}

function fields(o,allowed,required){if(!o||typeof o!=='object'||Array.isArray(o)||Object.keys(o).some(k=>!allowed.includes(k))||required.some(k=>o[k]===undefined))throw Error('Поля документа');}
function goodId(s){return typeof s==='string'&&/^[A-Za-z0-9_-]{1,64}$/.test(s);}
function title(s){return typeof s==='string'&&s.trim()&&new TextEncoder().encode(s).length<=96&&!/[\x00-\x1f\x7f]/.test(s);}
function validateDraft(d,bundledOnly){
 fields(d,['schedules','pre_minutes','pre_media','plans','mode','fixed_schedule','manual_media'],['schedules','pre_minutes','pre_media']);
 if(new TextEncoder().encode(JSON.stringify(d)).length>12288)throw Error('Черновик превышает 12 КиБ');
 const media={includes:v=>typeof v==='string'&&v.length<=64&&(['test','0','1','2','3','4'].includes(v)||(!bundledOnly&&/^user(?:[1-9][0-9]*|_[0-9a-f]+)$/.test(v)))};
 if(!Number.isInteger(d.pre_minutes)||d.pre_minutes<1||d.pre_minutes>10||!media.includes(d.pre_media)||d.manual_media!==undefined&&!media.includes(d.manual_media))throw Error('Параметры мелодий');
 if(d.mode!==undefined&&!['annual','fixed'].includes(d.mode))throw Error('Режим');
 if(!Array.isArray(d.schedules)||d.schedules.length>16)throw Error('Расписания');
 const ids=new Set();
 for(const sc of d.schedules){fields(sc,['id','name','rows','color'],['id','name','rows']);if(!goodId(sc.id)||sc.id==='quiet'||ids.has(sc.id)||!title(sc.name))throw Error('Расписание');ids.add(sc.id);
 if(sc.color!==undefined&&(!Number.isInteger(sc.color)||sc.color<1||sc.color>16))throw Error('Цвет');
 if(!Array.isArray(sc.rows))throw Error('Строки');const rows=new Set();
 for(const row of sc.rows){fields(row,['id','time','media','enabled','pre'],['id','time','media','enabled','pre']);if(!goodId(row.id)||rows.has(row.id)||typeof row.time!=='string'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(row.time)||!media.includes(row.media)||typeof row.enabled!=='boolean'||typeof row.pre!=='boolean')throw Error('Строка звонка');rows.add(row.id);}}
 if(d.fixed_schedule!==undefined&&d.fixed_schedule!=='quiet'&&!ids.has(d.fixed_schedule))throw Error('Ежедневное расписание');
 const plans=migrate(d.plans===undefined?[]:d.plans);for(const p of plans){if(p.schedule_ids.some(id=>!ids.has(id)))throw Error('Ссылка расписания');}return true;
}
const api={dates,validate,resize,migrate,suggest,ordinal,validateDraft};if(typeof module!=='undefined')module.exports=api;else root.RangePlans=api;
})(typeof window==='undefined'?globalThis:window);
