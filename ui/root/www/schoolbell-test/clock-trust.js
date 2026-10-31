(function(){
'use strict';
var root=document.getElementById('schedule-editor'),prepare=document.getElementById('trust-prepare'),policy=document.getElementById('trust-policy'),confirm=document.getElementById('trust-confirm'),review=document.getElementById('trust-review'),ack=document.getElementById('trust-rollback'),message=document.getElementById('trust-result');
var state=null,busy=false,challenge=null,deadline=0;
async function request(url,body){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},8000);try{var options={credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal};if(body){options.method='POST';options.body=new URLSearchParams(Object.assign({token:root.dataset.token},body));}var response=await fetch(url,options);if(!response.ok)throw Error('HTTP '+response.status);return await response.json();}finally{clearTimeout(timer);}}
function id(){var b=new Uint8Array(16);crypto.getRandomValues(b);return Array.from(b,function(v){return v.toString(16).padStart(2,'0');}).join('');}
async function command(body){
 var operation=id(),result=await request(root.dataset.trust,Object.assign({operation:operation},body));
 // A rejected submission is not retried. Once accepted, only GET may wait/retry.
 if(!result.ok)throw Error(result.code==='busy'?'Сейчас выполняется другая команда. Эта заявка не принята; дождитесь её окончания.':'Не удалось принять команду: '+result.code);
 var end=performance.now()+18000;
 while((result.pending || result.code==='busy') && performance.now()<end){
  await new Promise(function(resolve){setTimeout(resolve,500);});
  result=await request(root.dataset.trust+'?operation='+operation);
 }
 if(result.pending || result.code==='busy')throw Error('Исполнитель не завершил ответ за отведённое время. Проверьте состояние перед повтором. Операция '+operation);
 if(!result.ok)throw Error(result.code==='stale_confirmation'?'Подтверждение времени устарело. Снова запросите проверку времени и подтвердите показанную дату.':result.code==='clock_untrusted'?'Проверка времени прервана. Автозвонки не включены; проверьте состояние времени.':result.code==='mailbox_storage'?'Не удалось прочитать результат: ошибка хранилища команд. Проверьте состояние перед повтором.':result.code==='outcome_unknown'?'Связь с результатом операции потеряна. Проверьте состояние перед повтором.':'Операция не выполнена: '+result.code);
 return result;
}
window.schoolbellClockCommand=command;
window.addEventListener('schoolbell-time-changed',function(){challenge=null;review.hidden=true;state=null;document.getElementById('trust-status').textContent='Ожидаем новое состояние времени от исполнителя';draw();});
function draw(){prepare.disabled=busy || !state || !state.enforced;policy.disabled=busy || !state;policy.textContent=state && !state.enforced?'Включить контроль времени':'Отключить контроль времени';confirm.disabled=busy || !challenge || performance.now()>=deadline;}
window.addEventListener('schoolbell-clock-state',function(e){state=e.detail;var names={confirmed:'Время подтверждено',unconfirmed:'Время ещё не подтверждено',rollback_detected:'Обнаружен откат часов',review_required:'Требуется проверка времени',unchecked:'Время не проверяется'};document.getElementById('trust-status').textContent=state?(!state.enforced?'Контроль отключён. ': '')+(names[state.state] || state.state)+(state.reason?' · '+({observation_gap:'Прервалось наблюдение часов',manual_confirmation:'Подтверждено пользователем',startup:'После запуска требуется подтверждение',clock_step:'Обнаружен скачок часов'}[state.reason] || state.reason):''):'Нет свежего состояния исполнителя';draw();});
async function run(fn){if(busy)return;busy=true;message.textContent='Ожидаем ответ исполнителя…';draw();try{await fn();}catch(e){message.textContent=e.message || 'Связь прервана. Обновите состояние.';}finally{busy=false;draw();}}
prepare.addEventListener('click',function(){return run(async function(){challenge=null;review.hidden=true;var start=performance.now();var q=await command({action:'prepare'});challenge=q.challenge;deadline=start+14000;review.hidden=false;ack.checked=false;ack.parentElement.hidden=!q.rollback;document.getElementById('trust-date').textContent=(q.local_time?'На устройстве: '+q.local_time:'UTC: '+new Date(q.utc*1000).toISOString())+' · пояс устройства: '+q.zone+'. Местная дата и время — в верхней плашке.';message.textContent='Сверьте время и подтвердите в течение 15 секунд. Если не успели — запросите заново.';});});
confirm.addEventListener('click',function(){return run(async function(){if(!challenge || performance.now()>=deadline)throw Error('Время подтверждения истекло. Запросите заново.');var token=challenge;challenge=null;review.hidden=true;await command({action:'confirm',challenge:token,ack:String(ack.checked)});message.textContent='Время подтверждено. Автозвонки выключены; включите сохранённый план отдельно.';});});
policy.addEventListener('click',function(){if(!state || !window.confirm(state.enforced?'Отключить контроль времени? Неверная дата может привести к звонкам не в тот день. Автозвонки будут выключены.':'Включить контроль времени? Автозвонки будут выключены; потребуется подтверждение часов.'))return;var value=!state.enforced;return run(async function(){challenge=null;review.hidden=true;await command({action:'policy',enforced:String(value)});message.textContent='Настройка сохранена. Автозвонки выключены.';});});
setInterval(draw,500);
}());
