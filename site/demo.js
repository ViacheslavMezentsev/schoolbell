(function(){
'use strict';
var R=window.RangePlans;

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
// The simulator owns virtual time; no device requests or audible playback.
var simLast=performance.now();
function simulator(s){if(!s.sim){s.sim={epoch:Math.floor(Date.now()/1000),speed:0,audio:'ready',internet:'available',ntp:'synced',days:{},seen:{}};write(s);}return s.sim;}
function virtualNow(s){return simulator(s).epoch;}
function localDate(epoch,zone){return new Intl.DateTimeFormat('sv-SE',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(epoch*1000));}
function civil(epoch,zone){var t={};new Intl.DateTimeFormat('en-GB',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date(epoch*1000)).forEach(p=>t[p.type]=Number(p.value));return t;}
function eventEpoch(date,time,zone){var target=Date.parse(date+'T'+time+':00Z')/1000,e=target;for(var i=0;i<4;i++){var c=civil(e,zone),wall=Date.UTC(c.year,c.month-1,c.day,c.hour,c.minute,c.second)/1000,delta=target-wall;if(!delta)return e;e+=delta;}return null;}
function upcoming(s){if(!s.applied)return null;var date=localDate(virtualNow(s),s.zone);for(var i=0;i<367;i++,date=nextDate(date)){var events=preview(s.applied.data,date).events;for(var e of events){var utc=eventEpoch(date,e.time,s.zone);if(utc!==null && utc>virtualNow(s))return Object.assign({utc:utc},e);}}return null;}
function advance(s,target){
 var sim=simulator(s),from=sim.epoch;if(target<=from){sim.epoch=target;return;}
 if(s.autoEnabled && s.applied){
  var date=localDate(from,s.zone),last=localDate(target,s.zone),busyUntil=sim.busyUntil || 0;
  while(date<=last){
   if(sim.days[date]===undefined)sim.days[date]=0;
   for(var e of preview(s.applied.data,date).events){
    var due=eventEpoch(date,e.time,s.zone),id=[date,e.origin_date,e.schedule_id,e.row_id,e.kind].join('/');
    if(due===null || due<=from || due>target || sim.seen[id])continue;
    sim.seen[id]=true;
    var data=s.applied.data,sch=data.schedules.find(x=>x.id===e.schedule_id),plan=(data.plans || []).find(x=>x.id===data.active_plan);
    var bell={due:date.split('-').reverse().join('.')+' '+e.time,kind:e.kind,plan:data.mode==='fixed'?'По расписанию':plan && plan.name,schedule:sch && sch.name};
    log(s,'auto_requested','module','info',bell,due);
    var action=s.muted || due<busyUntil?'auto_skipped':sim.audio==='missing'?'auto_audio_unavailable':sim.audio==='error'?'auto_player_failed':'auto_ok';
    log(s,action,'module',action==='auto_ok'?'info':action==='auto_skipped'?'warning':'error',bell,due);
    if(action==='auto_ok'){sim.days[date]++;busyUntil=due+3;}
   }
   date=nextDate(date);
  }
  sim.busyUntil=busyUntil;
 }
 sim.epoch=target;
 var dates=Object.keys(sim.days).sort();while(dates.length>400)delete sim.days[dates.shift()];
 // Keep the same bounded history for duplicate protection across clock changes.
 var seenDates=[...new Set(Object.keys(sim.seen).map(x=>x.slice(0,10)))].sort();var oldest=seenDates.length>400?seenDates[seenDates.length-400]:null;
 if(oldest)Object.keys(sim.seen).forEach(k=>{if(k.slice(0,10)<oldest)delete sim.seen[k];});
 write(s);
}
function pump(s){var now=performance.now(),elapsed=Math.max(0,now-simLast);simLast=now;var sim=simulator(s);if(elapsed>0 && sim.speed){if(elapsed>10000){sim.speed=0;write(s);}else advance(s,sim.epoch+elapsed/1000*sim.speed);}}
function simulatedNetwork(s){var sim=simulator(s),config=s.networkConfig || {enabled:true,host:'1.1.1.1'};return {config:config,internet:{state:config.enabled?sim.internet:'disabled'},ntp:{state:sim.ntp}};}
function trimLog(s){while(new TextEncoder().encode(JSON.stringify(s.log)).length>(s.journalKiB || 32)*1024)s.log.shift();}
function log(s,action,source,level,bell,time){s.log.push({seq:++s.seq,time:Math.floor(time===undefined?virtualNow(s):time),source:source || 'user',level:level || 'info',action:action,bell:bell});trimLog(s);write(s);}
function assigned(data,date){if(data.mode==='fixed')return data.fixed_schedule && data.fixed_schedule!=='quiet'?data.fixed_schedule:false;var plan=R.migrate(data.plans || []).find(function(p){return p.id===data.active_plan && date>=p.start && date<=p.end;});if(!plan)return false;
 var index=R.ordinal(date)-R.ordinal(plan.start),c=plan.days[index];
 return c && c!=='.'?plan.schedule_ids[c.charCodeAt(0)-65]:false;}

function appliedContext(data,zone){
 var date=new Intl.DateTimeFormat('sv-SE',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(virtualNow(read())*1000));
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
 var name=u.pathname.slice(prefix.length),s=read(),body=new URLSearchParams(options && options.body),out;pump(s);
 if(name==='simulator'){
  var sim=simulator(s);
  if(options && options.method==='POST'){
   var command=body.get('command');
   if(command==='step'){var seconds=Number(body.get('seconds'));if(![60,3600,86400].includes(seconds))out={ok:false,code:'invalid'};else advance(s,sim.epoch+seconds);}
   else if(command==='next'){var next=upcoming(s);if(!next)out={ok:false,code:'no_next'};else advance(s,next.utc);}
   else if(command==='time'){var local=body.get('local'),epoch=Number(body.get('epoch'));if(local){try{R.ordinal(local.slice(0,10));epoch=/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(local)?eventEpoch(local.slice(0,10),local.slice(11,16),s.zone):null;if(epoch!==null)epoch+=Number(local.slice(17)||0);}catch(_){epoch=null;}}if(epoch===null||!Number.isFinite(epoch)||epoch<1577836800||epoch>2145916799)out={ok:false,code:'invalid'};else{sim.epoch=epoch;sim.busyUntil=0;log(s,'clock_set_ok');}}
   else if(command==='configure'){var speed=Number(body.get('speed')),audio=body.get('audio'),internet=body.get('internet'),ntp=body.get('ntp');if(![0,1,60,600].includes(speed)||!['ready','missing','error'].includes(audio)||!['available','unconfirmed'].includes(internet)||!['synced','waiting','disabled'].includes(ntp))out={ok:false,code:'invalid'};else Object.assign(sim,{speed:speed,audio:audio,internet:internet,ntp:ntp});}
   else out={ok:false,code:'invalid'};
   write(s);
  }
  if(!out)out={ok:true,sim:clone(sim),zone:s.zone,enabled:!!s.autoEnabled,next:upcoming(s)};
 }else if(name==='load')out={ok:true,active:false,data:clone(s.data),revision:String(s.revision)};
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
 if(!out)out={ok:true,state:s.autoEnabled?(s.muted?'muted':'running'):'disabled',enabled:!!s.autoEnabled,generation:s.autoGeneration || 0,revision:s.applied && s.applied.revision,context:s.applied && appliedContext(s.applied.data,s.zone),mode:s.applied && s.applied.data.mode,hardware:false,simulated:true,now:virtualNow(s),rate:simulator(s).speed,next:upcoming(s),cpu:{available:false,simulated:true}};}
 else if(name==='demo-boot' && options && options.method==='POST'){s.autoEnabled=false;simulator(s).speed=0;s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'device_boot','system');out={ok:true};}
 else if(name==='clock-trust'){
 if(options && options.method==='POST'){
 var action=body.get('action');out={ok:true};
 if(action==='set_prepare'){timeProposal={id:body.get('operation'),at:performance.now(),zone:s.zone};out={ok:true,simulated:true,challenge:timeProposal.id,utc:Math.floor(virtualNow(s)),zone:s.zone,ttl:60};}
 else if(action==='set_time'){
  var p=timeProposal;timeProposal=null;var epoch=Number(body.get('epoch'));
  if(!p || p.id!==body.get('challenge') || performance.now()-p.at>=60000 || p.zone!==s.zone || body.get('ack')!=='true')out={ok:false,code:'stale_confirmation'};
  else if(!Number.isInteger(epoch) || epoch<1577836800 || epoch>2145916799)out={ok:false,code:'calendar_range'};
  else{if(s.autoEnabled){s.autoEnabled=false;s.autoGeneration=(s.autoGeneration || 0)+1;log(s,'auto_disabled');}simulator(s).epoch=epoch;simulator(s).busyUntil=0;log(s,'clock_set_ok');out={ok:true,simulated:true,utc:Math.floor(virtualNow(s)),confirmation_required:false};}
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
 else if(name==='network'){s.networkConfig={enabled:body.get('enabled')==='true',host:body.get('host')};write(s);out={ok:true,network:simulatedNetwork(s)};}
 else if(name==='controls'){if(options && options.method==='POST'){if(body.has('confirm_play')){s.confirm_play=body.get('confirm_play')==='true';}else if(body.has('volume_db')){s.volume_db=Number(body.get('volume_db'));log(s,'volume_ok');}else{s.muted=body.get('muted')==='true';log(s,s.muted?'mute_on':'mute_off');}}out={ok:true,confirm_play:!!s.confirm_play,muted:!!s.muted,volume_db:s.volume_db || 0,playing:false,hardware:false,audio:{state:simulator(s).audio,controller:'USB',name:'Аудиокарта имитатора'},network:simulatedNetwork(s)};}
 else if(name==='metrics')out={ok:true,simulated:true,today:localDate(virtualNow(s),s.zone),days:Object.keys(simulator(s).days).sort().map(date=>({date:date,count:s.sim.days[date]})),max_days:400};
 else if(name==='journal' && options && options.method==='POST'){
  if(body.get('action')==='resize'){
   var kib=Number(body.get('kib')),old=s.journalKiB || 32;
   if(![16,32,64,128].includes(kib) || Number(body.get('expected'))!==old || (kib<old && body.get('confirmed')!=='true'))out={ok:false,code:'invalid'};
   else{s.journalKiB=kib;trimLog(s);write(s);out={ok:true,limit_bytes:kib*1024};}
  }else if(body.get('action')!=='clear')out={ok:false,code:'invalid'};
  else{s.log=[];write(s);out={ok:true};}
 }
 else if(name==='journal' && u.searchParams.get('action')==='limit')out={ok:true,limit_bytes:(s.journalKiB || 32)*1024};
 else if(name==='journal')out={ok:true,entries:clone(s.log).map(function(e){e.local_time=new Intl.DateTimeFormat('ru-RU',{timeZone:s.zone || 'UTC',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23',timeZoneName:'shortOffset'}).format(new Date(e.time*1000));return e;}),limit_bytes:(s.journalKiB || 32)*1024};
 else if(name==='clock'){
  var t={};new Intl.DateTimeFormat('en-GB',{timeZone:s.zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date(virtualNow(s)*1000)).forEach(function(p){t[p.type]=Number(p.value);});
  out={ok:true,zone:s.zone,epoch:Math.floor(virtualNow(s)),simulated:true,rate:simulator(s).speed,year:t.year,month:t.month,day:t.day,hour:t.hour,min:t.minute,sec:t.second};
 }else if(name==='timezone'){
  if(options && options.method==='POST'){
   var zone=body.get('zone');if(body.get('revision')!==s.zone)out={ok:false,code:'conflict'};
   else if(!zones().includes(zone))out={ok:false,code:'invalid_zone'};
   else{s.zone=zone;log(s,'timezone_ok');out={ok:true,zone:zone};}
  }else out={ok:true,zone:s.zone,revision:s.zone,zones:zones(),pending:false,runtime_ok:true};
 }else out={ok:false,state:'unavailable',code:'demo_only'};

 return new Response(JSON.stringify(out),{status:200,headers:{'Content-Type':'application/json'}});
};
var restored=read();if(restored.sim){restored.autoEnabled=false;restored.sim.speed=0;restored.autoGeneration=(restored.autoGeneration || 0)+1;log(restored,'device_boot','system');}
// Copy only on explicit consent; never overwrite new-site data or erase the old key.
var migrationButton=document.getElementById('demo-migrate'),migrationStatus=document.getElementById('demo-migration-status');
function legacyCandidate(){
 if(localStorage.getItem(key)!==null)return null;
 var raw=localStorage.getItem(legacyKey);if(raw===null)return null;
 var v=JSON.parse(raw);
 if(!v || v.format!==1 || !Number.isSafeInteger(v.revision) || v.revision<1 || !Array.isArray(v.log) || !Number.isSafeInteger(v.seq) || typeof v.zone!=='string' || !valid(v.data))throw new Error('legacy_invalid');
 return v;
}
try{if(legacyCandidate()){migrationButton.hidden=false;migrationStatus.textContent='Найден черновик прежней страницы. Можно скопировать его сюда; старая копия сохранится.';}}catch(_){migrationStatus.textContent='Прежнее хранилище недоступно или не прошло проверку. Оно не изменено; используйте экспорт .sbp из прежней страницы.';}
migrationButton.addEventListener('click',function(){
 var editor=window.schoolbellEditor,snapshot=editor && editor.portableSnapshot?editor.portableSnapshot():null;
 if(snapshot && (snapshot.dirty || snapshot.formPending || snapshot.busy || snapshot.reconcile)){migrationStatus.textContent='Сначала сохраните или отмените текущие правки.';return;}
 if(!confirm('Скопировать черновик прежней страницы? Старые данные останутся на месте. Имитация автозвонков будет выключена.'))return;
 try{var old=legacyCandidate();if(!old){migrationButton.hidden=true;migrationStatus.textContent='Перенос отменён: здесь уже есть сохранённые данные или прежний черновик отсутствует.';return;}
  var next=clone(old);next.autoEnabled=false;
  var raw=JSON.stringify(next);localStorage.setItem(key,raw);if(localStorage.getItem(key)!==raw)throw new Error('storage');
  memory=next;location.reload();
 }catch(_){migrationStatus.textContent='Не удалось перенести черновик. Прежнее хранилище не изменено; можно экспортировать .sbp на его странице.';}
});
document.getElementById('demo-reset').addEventListener('click',function(){if(confirm('Сбросить только данные этой страницы в вашем браузере?')){write(seed());location.reload();}});
document.getElementById('browser-audio').addEventListener('ended',function(){log(read(),'sample_requested');});
}());
