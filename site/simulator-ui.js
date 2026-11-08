(function(){
'use strict';
const $=id=>document.getElementById('simulator-'+id),fields=['speed','audio','internet','ntp'];
let busy=false,last=null,sequence=null,timeDirty=false;
async function api(body){const r=await fetch('./demo-api/simulator',body?{method:'POST',body:new URLSearchParams(body)}:undefined);const v=await r.json();if(!v.ok)throw Error(v.code==='no_next'?'В применённом плане нет следующего звонка в пределах года.':'Не удалось применить значение.');return v;}
function parts(epoch,zone){let p={};new Intl.DateTimeFormat('en-GB',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date(epoch*1000)).forEach(x=>p[x.type]=x.value);return p;}
function draw(v){last=v;let p=parts(v.sim.epoch,v.zone),time=p.hour+':'+p.minute+':'+p.second,date=p.day+'.'+p.month+'.'+p.year;
 $('now').textContent=date+' · '+time;
 $('summary').textContent=time+' · '+(v.sim.speed?'×'+v.sim.speed:'Пауза')+' · '+({ready:'Аудио подключено',missing:'Аудио отключено',error:'Ошибка аудио'}[v.sim.audio]);
 $('zone').textContent='· '+v.zone;
 if(!timeDirty)$('time').value=p.year+'-'+p.month+'-'+p.day+'T'+time;
 fields.forEach(k=>{if(document.activeElement!==$(k))$(k).value=String(v.sim[k]);});
 $('next').disabled=!v.next || busy;$('next').title=v.next?v.next.date+' '+v.next.time+' · '+(v.next.kind==='pre'?'Предзвонок':'Основной звонок'):'Сначала примените план с будущими звонками';
}
function refreshShared(clockChanged){if(clockChanged)window.dispatchEvent(new CustomEvent('schoolbell-time-changed'));window.dispatchEvent(new CustomEvent('schoolbell-simulator-update'));}
async function run(body,message){if(busy)return;busy=true;try{const value=await api(body);if(body.command==='time')timeDirty=false;draw(value);$('result').textContent=message;refreshShared(true);}catch(e){$('result').textContent=e.message;}finally{busy=false;if(last)draw(last);}}
$('time').addEventListener('input',()=>{timeDirty=true;});
fields.forEach(k=>$(k).addEventListener('change',()=>{let body={command:'configure'};fields.forEach(f=>body[f]=$(f).value);run(body,'Состояние имитатора обновлено.');}));
$('set-time').addEventListener('click',()=>run({command:'time',local:$('time').value},'Виртуальное время установлено. Пропущенные звонки не выполнялись.'));
$('minute').addEventListener('click',()=>run({command:'step',seconds:60},'Время продвинуто на минуту. Результаты — в журнале и карте.'));
$('next').addEventListener('click',()=>run({command:'next'},'Время переведено к следующему звонку. Результат — в журнале и карте.'));
$('reboot').addEventListener('click',async()=>{if(!confirm('Имитировать перезагрузку? Автозвонки выключатся, настройки и история сохранятся.'))return;await fetch('./demo-api/demo-boot',{method:'POST'});await poll();refreshShared(true);$('result').textContent='Перезагрузка выполнена. Автозвонки выключены.';});
async function poll(){if(busy || document.hidden)return;try{const v=await api();draw(v);const signature=JSON.stringify([v.sim.speed,v.sim.audio,v.sim.internet,v.sim.ntp,v.zone,parts(v.sim.epoch,v.zone).day,Object.keys(v.sim.seen).length,v.enabled]);if(sequence!==signature){sequence=signature;refreshShared(false);}}catch(e){$('result').textContent=e.message;}}
setInterval(poll,1000);poll();
}());
