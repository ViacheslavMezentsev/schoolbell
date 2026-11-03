(function(){
'use strict';
var root=document.getElementById('schedule-editor');
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
 if(!result.ok)throw Error(result.code==='stale_confirmation'?'Подтверждение времени устарело. Снова запросите проверку времени и подтвердите показанную дату.':result.code==='mailbox_storage'?'Не удалось прочитать результат: ошибка хранилища команд. Проверьте состояние перед повтором.':result.code==='outcome_unknown'?'Связь с результатом операции потеряна. Проверьте состояние перед повтором.':'Операция не выполнена: '+result.code);
 return result;
}
window.schoolbellClockCommand=command;
}());
