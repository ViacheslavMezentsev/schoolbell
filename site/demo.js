(function(){
'use strict';
var R=window.RangePlans;
var queueBins=[],demoStarted=performance.now();
function queueDemo(record,ok){
 var now=Math.floor(performance.now()/1000),key=Math.floor(now/5);
 queueBins=queueBins.filter(function(b){return b.key>key-12;});
 if(record){var b=queueBins.find(function(b){return b.key===key;});if(!b){b={key:key,depth:1,running:1,processed:0,failed:0,expired:0,wait_count:0,wait_sum:0,wait_max:0};queueBins.push(b);}b.processed++;b.wait_count++;if(!ok)b.failed++;}
 return {available:true,simulated:true,epoch:'demo',now:now,at:now,depth:0,running:0,bins:queueBins};
}
var key='schoolbell-public-demo-v1',legacyKey='openwrt-schoolbell-public-demo-v1',memory=null;
function clone(v){return JSON.parse(JSON.stringify(v));}
function iso(d){return d.toISOString().slice(0,10);}
function nextDate(day){var d=new Date(day+'T00:00:00Z');d.setUTCDate(d.getUTCDate()+1);return iso(d);}
function seed(){var year=new Date().getFullYear(),date=year+'-01-01',days='';
 while(Number(date.slice(0,4))===year){var w=new Date(date+'T00:00:00Z').getUTCDay();days+=w===0 || w===6?'.':w===5?'B':'A';date=nextDate(date);}
 function rows(times){return times.map(function(time,i){return {id:'r'+i,time:time,media:'test',enabled:true,pre:i===0};});}
 return {format:1,revision:1,zone:Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',log:[],seq:0,data:{mode:'annual',active_plan:'year-'+year,pre_minutes:2,pre_media:'test',schedules:[
 {id:'normal',name:'Обычный день',color:1,rows:rows(['08:30','09:15','09:25','10:10','10:30','11:15'])},
 {id:'short',name:'Короткие уроки',color:2,rows:rows(['08:30','09:00','09:10','09:40'])},
 {id:'exam',name:'Экзамены',color:7,rows:rows(['09:00','12:00'])}],plans:[{id:'year-'+year,name:'Учебный пример '+year,start:year+'-01-01',end:year+'-12-31',schedule_ids:['normal','short','exam'],days:days},{id:'exam-'+(year+1),name:'Экзаменационная неделя',start:(year+1)+'-06-01',end:(year+1)+'-06-07',schedule_ids:['exam'],days:'AAAAA..'}]}};}
function read(){try{var value=JSON.parse(localStorage.getItem(key));if(value && value.format===1 && value.data && Array.isArray(value.log)){memory=value;return value;}}catch(_){}if(!memory)memory=seed();return memory;}
window.schoolbellDemo={portableState:function(){return {automatic_enabled:!!read().autoEnabled};}};
function write(v){memory=v;try{localStorage.setItem(key,JSON.stringify(v));}catch(_){document.getElementById('demo-storage').textContent='Хранилище браузера недоступно: изменения живут только в этой вкладке.';}}
function log(s,action,source){s.log.push({seq:++s.seq,time:Math.floor(Date.now()/1000),source:source || 'user',level:'info',action:action});while(new TextEncoder().encode(JSON.stringify(s.log)).length>32768)s.log.shift();write(s);}
function assigned(data,date){if(data.mode==='fixed')return data.fixed_schedule && data.fixed_schedule!=='quiet'?data.fixed_schedule:false;var plan=R.migrate(data.plans || []).find(function(p){return p.id===data.active_plan && date>=p.start && date<=p.end;});if(!plan)return false;
 var index=R.ordinal(date)-R.ordinal(plan.start),c=plan.days[index];
 return c && c!=='.'?plan.schedule_ids[c.charCodeAt(0)-65]:false;}

function appliedContext(data,zone){
 var date=new Intl.DateTimeFormat('sv-SE',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
 var result=data.mode==='fixed'?{fixed_id:data.fixed_schedule || 'quiet'}:{};
 if(data.mode!=='fixed'){
  var plan=R.migrate(data.plans || []).find(p=>p.id===data.active_plan);
  if(!plan)return {day:'no_plan'};
  result.plan=plan.name;result.plan_id=plan.id;
  if(date<plan.start || date>plan.end)return {plan:plan.name,plan_id:plan.id,day:'outside'};
 }
 var schedule=data.schedules.find(s=>s.id===assigned(data,date));
 result.day=schedule?(schedule.rows.some(r=>r.enabled)?'scheduled':'empty'):'quiet';
 if(schedule)result.schedule=schedule.name;
 return result;
}
function preview(data,date){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(date+'T00:00:00Z')) || iso(new Date(date+'T00:00:00Z'))!==date)return {ok:false,code:'date'};
 var selected=assigned(data,date),events=[];
 if(selected && data.schedules.some(function(s){return s.id===selected && s.rows.some(function(row){return row.enabled;});}))(date==='9999-12-31'?[date]:[date,nextDate(date)]).forEach(function(origin){var sid=assigned(data,origin),schedule=data.schedules.find(function(s){return s.id===sid;});if(!schedule)return;
  schedule.rows.forEach(function(row){if(!row.enabled)return;var a=row.time.split(':').map(Number),minutes=a[0]*60+a[1];
   function event(m,kind){events.push({date:date,time:String(Math.floor(m/60)).padStart(2,'0')+':'+String(m%60).padStart(2,'0'),origin_date:origin,schedule_id:sid,row_id:row.id,kind:kind,media:kind==='pre'?data.pre_media:row.media});}
   if(origin===date)event(minutes,'main');
   var pre=minutes-data.pre_minutes;if(row.pre && ((origin===date && pre>=0) || (origin!==date && pre<0)))event((pre+1440)%1440,'pre');
  });
 });
 events.sort(function(a,b){return a.time.localeCompare(b.time) || (a.origin_date+'/'+a.schedule_id+'/'+a.row_id+'/'+a.kind).localeCompare(b.origin_date+'/'+b.schedule_id+'/'+b.row_id+'/'+b.kind);});
 return {ok:true,active:false,clock_basis:'civil',date:date,selected_schedule:selected || 'quiet',events:events};
}
function runningSourceChange(state,draft){
 if(!state.autoEnabled || !state.applied)return '';
 var applied=state.applied.data,fixed=applied.mode==='fixed',id=fixed?applied.fixed_schedule:applied.active_plan;
 function source(config){return (fixed?config.schedules:R.migrate(config.plans || [])).find(x=>x.id===id);}
 var before=source(state.data),after=source(draft);
 return before && JSON.stringify(before)!==JSON.stringify(after)?before.name || id:'';
}
let cachedPreview=null;
function previewRequest(text,date){
 if(cachedPreview && cachedPreview.text===text && cachedPreview.date===date)return clone(cachedPreview.result);
 const data=JSON.parse(text),result=valid(data)?preview(data,date):{ok:false,code:'invalid'};
 if(result.ok && new TextEncoder().encode(text+JSON.stringify(result)).length<=32740)cachedPreview={text,date,result};
 return result;
}
function valid(d){try{return R.validateDraft(d,true);}catch(_){return false;}}
function zones(){var z=Intl.supportedValuesOf?Intl.supportedValuesOf('timeZone'):['Europe/Moscow','Asia/Yekaterinburg','Europe/Berlin','America/New_York'];return ['UTC'].concat(z);}
var timeProposal=null;
var prefix=new URL('./demo-api/',location.href).pathname;
window.fetch=async function(url,options){
 var u=new URL(url,location.href);if(u.origin!==location.origin || !u.pathname.startsWith(prefix))throw new Error('The demo has no remote API');
 var name=u.pathname.slice(prefix.length),s=read(),body=new URLSearchParams(options && options.body),out;
 if(name==='load')out={ok:true,active:false,data:clone(s.data),revision:String(s.revision)};
 else if(name==='save'){
  var d;try{d=JSON.parse(body.get('draft'));}catch(_){}
  if(body.get('revision')!==String(s.revision))out={ok:false,code:'conflict'};
  else if(!valid(d) || new TextEncoder().encode(JSON.stringify(d)).length>12288)out={ok:false,code:'invalid'};
  else if(s.data.mode==='fixed' && s.data.schedules.some(x=>x.id===s.data.fixed_schedule) && !d.schedules.some(x=>x.id===s.data.fixed_schedule))out={ok:false,code:'schedule_in_use'};
  else if(s.data.mode!=='fixed' && R.migrate(s.data.plans || []).some(x=>x.id===s.data.active_plan) && !R.migrate(d.plans || []).some(x=>x.id===s.data.active_plan))out={ok:false,code:'plan_in_use'};
  else if(s.applied && s.applied.data.mode!=='fixed' &&
    R.migrate(s.data.plans || []).some(p=>p.id===s.applied.data.active_plan) &&
    !R.migrate(d.plans || []).some(p=>p.id===s.applied.data.active_plan))out={ok:false,code:'plan_in_use'};
  else if(s.applied && s.applied.data.mode==='fixed' &&
    s.data.schedules.some(item=>item.id===s.applied.data.fixed_schedule) &&
    !d.schedules.some(item=>item.id===s.applied.data.fixed_schedule))out={ok:false,code:'schedule_in_use'};
  else if(runningSourceChange(s,d))out={ok:false,code:'source_running',detail:{name:runningSourceChange(s,d)}};
  else{s.data=d;s.revision++;log(s,'save_ok');out={ok:true,active:false,data:clone(d),revision:String(s.revision)};}
 }else if(name==='preview'){try{out=previewRequest(body.get('draft'),body.get('date'));}catch(_){out={ok:false,code:'invalid'};}}
 else if(name==='media')out={ok:true,demo:true,generation:0,storage:{total_kib:4096,free_kib:1536,used_kib:2560,reserve_kib:512,media_kib:0},slots:['test','0','1','2','3','4'].map(function(id,i){return {id:id,name:i<6?id+'.mp3':'Свободная позиция',title:['Тестовый звонок','[Короткая] Время','Шутка Баха','Гостья из будущего','Князь Игорь','Усатый нянь'][i] || ('Пользовательская '+(i-5)),source:i<6?'bundled':'empty',size_bytes:[13104,41273,63321,69904,68023,82368][i] || 0};})};
 else if(name==='automatic'){
 if(options && options.method==='POST' && body.get('action')==='apply'){
  if(body.get('revision')!==String(s.revision))out={ok:false,code:'draft_conflict'};
  else if(appliedContext(s.data,s.zone).day==='no_plan')out={ok:false,code:'select_plan'};
  else {s.applied={revision:String(s.revision),data:clone(s.data)};s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'draft_applied');}
 }
 if(options && options.method==='POST' && body.get('enabled')==='false'){s.autoEnabled=false;s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'auto_disabled');}
 if(!out)out={ok:true,state:s.autoEnabled?(s.muted?'muted':'running'):'disabled',enabled:!!s.autoEnabled,generation:s.autoGeneration || 0,revision:s.applied && s.applied.revision,context:s.applied && appliedContext(s.applied.data,s.zone),mode:s.applied && s.applied.data.mode,hardware:false,simulated:true,queue:queueDemo(false),cpu:{available:false,simulated:true,storage:{total_kib:4096,free_kib:1536},uptime_seconds:Math.max(0,Math.floor((performance.now()-demoStarted)/1000))}};}
 else if(name==='demo-boot' && options && options.method==='POST'){s.autoEnabled=false;s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'device_boot','system');out={ok:true};}
 else if(name==='clock-trust'){
 if(options && options.method==='POST'){
 var action=body.get('action');out={ok:true};
 if(action==='set_prepare'){timeProposal={id:body.get('operation'),at:performance.now(),zone:s.zone};out={ok:true,simulated:true,challenge:timeProposal.id,utc:Math.floor(Date.now()/1000),zone:s.zone,ttl:60};}
 else if(action==='set_time'){
  var p=timeProposal;timeProposal=null;var epoch=Number(body.get('epoch'));
  if(!p || p.id!==body.get('challenge') || performance.now()-p.at>=60000 || p.zone!==s.zone || body.get('ack')!=='true')out={ok:false,code:'stale_confirmation'};
  else if(!Number.isInteger(epoch) || epoch<1577836800 || epoch>2145916799)out={ok:false,code:'calendar_range'};
  else{log(s,'clock_set_ok');out={ok:true,simulated:true,utc:Math.floor(Date.now()/1000),confirmation_required:false};}
 }
 else if(action==='enable')out={ok:false,code:'reload_interface'};
 else if(action==='resume'){
  if(!s.applied || s.autoEnabled || body.get('revision')!==s.applied.revision || body.get('generation')!==String(s.autoGeneration))out={ok:false,code:'active_conflict'};
  else if(appliedContext(s.applied.data,s.zone).day==='no_plan')out={ok:false,code:'select_plan'};
  else{s.autoEnabled=true;s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'auto_enabled');out={ok:true,generation:s.autoGeneration};}
 }
 else out={ok:false,code:'demo_no_hardware'};
 }else out={ok:false,code:'demo_no_pending'};
 }
 else if(name==='controls'){if(options && options.method==='POST'){if(body.has('volume_db')){s.volume_db=Number(body.get('volume_db'));log(s,'volume_ok');}else{s.muted=body.get('muted')==='true';log(s,s.muted?'mute_on':'mute_off');}}out={ok:true,muted:!!s.muted,volume_db:s.volume_db || 0,playing:false,hardware:false,audio:{state:"demo"}};}
 else if(name==='metrics')out={ok:true,demo:true,today:new Intl.DateTimeFormat('sv-SE',{timeZone:s.zone || 'UTC',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date()),days:[],max_days:400};
 else if(name==='journal')out={ok:true,entries:clone(s.log).map(function(e){e.local_time=new Intl.DateTimeFormat('ru-RU',{timeZone:s.zone || 'UTC',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23',timeZoneName:'shortOffset'}).format(new Date(e.time*1000));return e;}),limit_bytes:32768};
 else if(name==='clock'){
  var t={};new Intl.DateTimeFormat('en-GB',{timeZone:s.zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date()).forEach(function(p){t[p.type]=Number(p.value);});
  out={ok:true,zone:s.zone,epoch:Math.floor(Date.now()/1000),year:t.year,month:t.month,day:t.day,hour:t.hour,min:t.minute,sec:t.second};
 }else if(name==='timezone'){
  if(options && options.method==='POST'){
   var zone=body.get('zone');if(body.get('revision')!==s.zone)out={ok:false,code:'conflict'};
   else if(!zones().includes(zone))out={ok:false,code:'invalid_zone'};
   else{s.zone=zone;log(s,'timezone_ok');out={ok:true,zone:zone};}
  }else out={ok:true,zone:s.zone,revision:s.zone,zones:zones(),pending:false,runtime_ok:true};
 }else out={ok:false,state:'unavailable',code:'demo_only'};
 if(name==='clock-trust'&&options&&options.method==='POST')queueDemo(true,out.ok);
 return new Response(JSON.stringify(out),{status:200,headers:{'Content-Type':'application/json'}});
};
// Copy only on explicit consent; never overwrite new-site data or erase the old key.
var migrationButton=document.getElementById('demo-migrate'),migrationStatus=document.getElementById('demo-migration-status');
function legacyCandidate(){
 if(localStorage.getItem(key)!==null)return null;
 var raw=localStorage.getItem(legacyKey);if(raw===null)return null;
 var v=JSON.parse(raw);
 if(!v || v.format!==1 || !Number.isSafeInteger(v.revision) || v.revision<1 || !Array.isArray(v.log) || !Number.isSafeInteger(v.seq) || typeof v.zone!=='string' || !valid(v.data))throw new Error('legacy_invalid');
 return v;
}
try{if(legacyCandidate()){migrationButton.hidden=false;migrationStatus.textContent='Найден черновик прежнего демо. Можно скопировать его сюда; старая копия сохранится.';}}catch(_){migrationStatus.textContent='Прежнее хранилище недоступно или не прошло проверку. Оно не изменено; используйте экспорт .sbp из прежнего демо.';}
migrationButton.addEventListener('click',function(){
 var editor=window.schoolbellEditor,snapshot=editor && editor.portableSnapshot?editor.portableSnapshot():null;
 if(snapshot && (snapshot.dirty || snapshot.formPending || snapshot.busy || snapshot.reconcile)){migrationStatus.textContent='Сначала сохраните или отмените текущие правки демо.';return;}
 if(!confirm('Скопировать черновик прежнего демо? Старые данные останутся на месте. Имитация автозвонков будет выключена.'))return;
 try{var old=legacyCandidate();if(!old){migrationButton.hidden=true;migrationStatus.textContent='Перенос отменён: здесь уже есть сохранённые данные или прежний черновик отсутствует.';return;}
  var next=clone(old);next.autoEnabled=false;
  var raw=JSON.stringify(next);localStorage.setItem(key,raw);if(localStorage.getItem(key)!==raw)throw new Error('storage');
  memory=next;location.reload();
 }catch(_){migrationStatus.textContent='Не удалось перенести черновик. Прежнее демо не изменено; можно экспортировать .sbp на его странице.';}
});
document.getElementById('demo-boot').addEventListener('click',async function(){
 if(!confirm('Имитировать перезагрузку? Автозвонки демо будут выключены.'))return;
 await window.fetch('./demo-api/demo-boot',{method:'POST'});
 window.dispatchEvent(new CustomEvent('schoolbell-diagnostic-refresh'));
});
document.getElementById('demo-reset').addEventListener('click',function(){if(confirm('Сбросить только данные этого демо в вашем браузере?')){write(seed());location.reload();}});
document.getElementById('browser-audio').addEventListener('ended',function(){log(read(),'sample_requested');});
}());
