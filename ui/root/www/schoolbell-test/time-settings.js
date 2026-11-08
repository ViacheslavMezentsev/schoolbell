(function(){
'use strict';
var root=document.getElementById('schedule-editor'),button=document.getElementById('time-prepare'),message=document.getElementById('time-result'),reload=document.getElementById('time-reload');
var busy=false,reading=false;
function draw(){var blocked=window.schoolbellSessionBlocked;button.disabled=busy || blocked;reload.disabled=busy || blocked;}
function explain(e){var names={sound_busy:'Сейчас играет мелодия. Дождитесь окончания или остановите звук.',disable_failed:'Не удалось выключить автозвонки. Часы не изменены.',clock_set_failed:'Системная команда не подтвердила установку часов.',clock_verify_failed:'Показания после установки не совпали с ожидаемыми.',clock_request_expired:'Заявка задержалась; подготовьте новую после сверки.',browser_clock_changed:'Часы браузера изменились; начните сверку заново.',calendar_range:'Поддерживаются даты с 2020 по 2037 год.',clock_cleanup_failed:'Не удалось освободить ресурсы операции. Требуется диагностика.'};for(var code in names)if(e.message.indexOf(code)>=0)return names[code];return e.message;}
function clockParts(date,zone){
 return new Intl.DateTimeFormat('ru-RU',{timeZone:zone,day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(date);
}
function paintTime(id,parts,other,zone,otherZone){
 var node=document.getElementById(id);node.textContent='';
 parts.forEach(function(part){
  var span=document.createElement('span');span.textContent=part.value;
  if(other && part.type!=='literal' && part.value!==other.find(function(p){return p.type===part.type;}).value)span.className='clock-difference';
  node.appendChild(span);
 });
 var suffix=document.createElement('span');suffix.textContent=' · '+zone;
 if(otherZone && zone!==otherZone)suffix.className='clock-difference';
 node.appendChild(suffix);
}
function browserTime(){var zone=Intl.DateTimeFormat().resolvedOptions().timeZone;paintTime('time-browser',clockParts(new Date(),zone),null,zone);}
async function read(){
 if(reading)return;reading=true;var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},10000),start=performance.now();
 try{var response=await fetch(root.dataset.clock,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});if(!response.ok)throw Error();var v=await response.json(),rtt=performance.now()-start;
 if(!v.ok || !Number.isFinite(v.epoch) || rtt>2000)throw Error();
 var browserZone=Intl.DateTimeFormat().resolvedOptions().timeZone,deviceZone=v.zone || 'UTC';
 var browserNow=Date.now(),device=clockParts(new Date(v.epoch*1000),deviceZone),browser=clockParts(new Date(browserNow),browserZone);
 paintTime('time-device',device,browser,deviceZone,browserZone);
 paintTime('time-browser',browser,device,browserZone,deviceZone);
 var difference=Math.floor(browserNow/1000)-Math.floor(v.epoch);
 document.getElementById('time-difference').textContent=(difference===0?'Показания совпадают с точностью до секунды.':'По показанным значениям часы устройства '+(difference>0?'отстают':'спешат')+' на '+Math.abs(difference)+' с.')+' Показания на момент чтения; для обновления нажмите ↻.';
 }catch(_){browserTime();document.getElementById('time-device').textContent='Показания устройства не подтверждены. Повторите чтение.';document.getElementById('time-difference').textContent='';}
 finally{clearTimeout(timer);reading=false;}
}
button.addEventListener('click',async function(){
 if(busy || window.schoolbellSessionBlocked)return;
 busy=true;draw();message.textContent='Читаем время для подтверждения…';
 var wall=Date.now(),start=performance.now(),submitted=false;
 try{
  var q=await window.schoolbellClockCommand({action:'set_prepare',epoch:String(Math.floor(wall/1000))});
  if(performance.now()-start>10000)throw Error('Ответ задержался. Повторите установку; часы не менялись.');
  if(window.schoolbellSessionBlocked)throw Error('Сеанс завершён. Войдите снова; часы не менялись.');
  var zone=Intl.DateTimeFormat().resolvedOptions().timeZone;
  function format(epoch){return clockParts(new Date(epoch),zone).map(function(p){return p.value;}).join('');}
  var text='Установить время из браузера?\n\n'+(q.simulated?'Виртуальные часы: ':'На Школьнике: ')+format(q.utc*1000)+'\nВ браузере: '+format(Date.now())+'\nЧасовой пояс сравнения: '+zone+'\n\nАвтозвонки будут выключены. Пропущенные звонки не проигрываются.';
  if(!window.confirm(text)){message.textContent='Отменено. Часы не менялись.';return;}
  var elapsed=performance.now()-start;
  if(window.schoolbellSessionBlocked)throw Error('Сеанс завершён. Войдите снова; часы не менялись.');
  if(elapsed<0 || elapsed>=60000 || Math.abs(Date.now()-wall-elapsed)>2000){message.textContent='Подтверждение устарело или часы браузера изменились. Нажмите «Установить время из браузера» заново.';return;}
  message.textContent='Устанавливаем время. Не повторяйте запрос…';submitted=true;
  var result=await window.schoolbellClockCommand({action:'set_time',challenge:q.challenge,epoch:String(Math.floor(Date.now()/1000)),ack:'true'});
  message.textContent=result.simulated?'Виртуальные часы установлены по времени браузера. Часы компьютера не менялись.':'Время установлено и проверено. Автозвонки выключены.';
 }catch(e){message.textContent=submitted?'Установка не подтверждена: '+explain(e)+' Сначала обновите показания; запрос автоматически не повторяется.':explain(e);}
 finally{busy=false;draw();if(submitted){window.dispatchEvent(new Event('schoolbell-time-changed'));await read();}}
});
reload.addEventListener('click',read);
window.addEventListener('schoolbell-session-lost',draw);
window.addEventListener('schoolbell-session-restored',draw);
var section=document.getElementById('time-settings');
section.addEventListener('toggle',function(){if(section.open)read();});
browserTime();if(section.open)read();draw();
}());
