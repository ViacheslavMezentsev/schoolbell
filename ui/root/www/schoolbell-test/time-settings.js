(function(){
'use strict';
var root=document.getElementById('schedule-editor'),button=document.getElementById('time-prepare'),confirm=document.getElementById('time-confirm'),cancel=document.getElementById('time-cancel'),review=document.getElementById('time-review'),message=document.getElementById('time-result'),reload=document.getElementById('time-reload');
var busy=false,proposal=null,reading=false;
function draw(){var blocked=window.schoolbellSessionBlocked;button.disabled=busy || blocked;confirm.disabled=busy || blocked || !proposal;cancel.disabled=busy;reload.disabled=busy || blocked;}
function explain(e){var names={sound_busy:'Сейчас играет мелодия. Дождитесь окончания или остановите звук.',disable_failed:'Не удалось выключить автозвонки. Часы не изменены.',clock_set_failed:'Системная команда не подтвердила установку часов.',clock_verify_failed:'Показания после установки не совпали с ожидаемыми.',clock_request_expired:'Заявка задержалась; подготовьте новую после сверки.',browser_clock_changed:'Часы браузера изменились; начните сверку заново.',calendar_range:'Поддерживаются даты с 2020 по 2037 год.',clock_cleanup_failed:'Не удалось освободить ресурсы операции. Требуется диагностика.'};for(var code in names)if(e.message.indexOf(code)>=0)return names[code];return e.message;}
function browserTime(){document.getElementById('time-browser').textContent='В браузере: '+new Date().toLocaleString('ru-RU',{hour12:false})+' · '+Intl.DateTimeFormat().resolvedOptions().timeZone;}
async function read(){
 if(reading)return;reading=true;var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},10000),start=performance.now();
 try{var response=await fetch(root.dataset.clock,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});if(!response.ok)throw Error();var v=await response.json(),rtt=performance.now()-start;
 if(!v.ok || !Number.isFinite(v.epoch) || rtt>2000)throw Error();
 document.getElementById('time-device').textContent='На устройстве: '+[v.day,v.month,v.year].join('.')+' '+[v.hour,v.min,v.sec].map(function(n){return String(n).padStart(2,'0');}).join(':')+' · '+(v.zone || 'UTC');
 document.getElementById('time-difference').textContent='Разница с браузером: около '+Math.round((Date.now()-v.epoch*1000-rtt/2)/1000)+' с. Показания на момент чтения.';
 }catch(_){document.getElementById('time-device').textContent='Показания устройства не подтверждены. Повторите чтение.';document.getElementById('time-difference').textContent='';}
 finally{clearTimeout(timer);reading=false;browserTime();}
}
button.addEventListener('click',async function(){
 if(busy || window.schoolbellSessionBlocked)return;busy=true;proposal=null;review.hidden=true;draw();message.textContent='Читаем время для подтверждения…';
 var wall=Date.now(),start=performance.now();
 try{
 var q=await window.schoolbellClockCommand({action:'set_prepare',epoch:String(Math.floor(wall/1000))});
 if(performance.now()-start>10000)throw Error('Ответ задержался. Повторите подготовку; часы не менялись.');
 proposal={id:q.challenge,wall:wall,mono:start,simulated:q.simulated===true};review.hidden=false;
 document.getElementById('time-proposal').textContent=(q.simulated?'ДЕМО — только имитация. ':'')+'Устройство: '+new Date(q.utc*1000).toLocaleString('ru-RU',{timeZone:'UTC',hour12:false})+' UTC. Браузер: '+new Date(wall).toLocaleString('ru-RU',{hour12:false})+'. Изменение: около '+Math.round(wall/1000-q.utc)+' с.';
 message.textContent='Сверьте обе даты. Подтверждение доступно одну минуту; при установке учитывается прошедшее время.';
 }catch(e){message.textContent=explain(e);}
 finally{busy=false;draw();}
});
cancel.addEventListener('click',function(){proposal=null;review.hidden=true;message.textContent='Отменено. Часы не менялись.';draw();});
confirm.addEventListener('click',async function(){
 if(busy || window.schoolbellSessionBlocked || !proposal)return;
 var p=proposal;proposal=null;review.hidden=true;var elapsed=performance.now()-p.mono;
 if(elapsed<0 || elapsed>=60000 || Math.abs(Date.now()-p.wall-elapsed)>2000){message.textContent='Подтверждение устарело или часы браузера изменились. Запросите установку заново.';draw();return;}
 busy=true;draw();message.textContent='Устанавливаем время. Не повторяйте запрос…';
 try{
 var q=await window.schoolbellClockCommand({action:'set_time',challenge:p.id,epoch:String(Math.floor(Date.now()/1000)),ack:'true'});
 message.textContent=(q.simulated?'ДЕМО: установка имитирована. Реальные часы не менялись. ':'Время установлено и проверено. ')+'Автозвонки выключены. Сверьте показания и подтвердите время в этом блоке; включение плана выполняется отдельно.';
 }catch(e){message.textContent='Установка не подтверждена: '+explain(e)+' Сначала обновите показания; запрос автоматически не повторяется.';}
 finally{busy=false;draw();window.dispatchEvent(new Event('schoolbell-time-changed'));await read();}
});
reload.addEventListener('click',read);
window.addEventListener('schoolbell-session-lost',function(){proposal=null;review.hidden=true;draw();});
window.addEventListener('schoolbell-session-restored',function(){proposal=null;draw();});
browserTime();read();draw();
}());
