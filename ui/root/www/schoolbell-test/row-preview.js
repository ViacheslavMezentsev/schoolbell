(function(){
'use strict';
var root=document.getElementById('schedule-editor'),audio=document.getElementById('row-preview-audio'),status=document.getElementById('row-preview-status'),pending=false;
var demo=root.dataset.load.indexOf('demo-api')>=0;
function stop(){audio.pause();audio.removeAttribute('src');audio.load();audio.hidden=true;}
window.schoolbellRowPreview=async function(id,hardware){
 if(!/^(test|[0-4]|user(?:[1-9][0-9]*|_[0-9a-f]+))$/.test(id))return;
 if(window.schoolbellSessionBlocked){status.textContent='Войдите для прослушивания.';return;}
 if(hardware && demo){status.textContent='Через Школьника недоступно: демо без оборудования.';return;}
 if(pending){status.textContent='Дождитесь завершения предыдущего запроса. Повторно не запускаем.';return;}
 if(demo && /^user/.test(id)){status.textContent='В демо доступны только штатные мелодии.';return;}
 if(!hardware){
  stop();audio.hidden=false;audio.src=demo?root.dataset.sample.replace(/test\.mp3$/,encodeURIComponent(id)+'.mp3'):root.dataset.sample+'?id='+encodeURIComponent(id);
  status.textContent='В браузере — на компьютере или телефоне.';
  try{await audio.play();}catch(_){status.textContent='Не удалось прослушать мелодию. Проверьте наличие файла и вход.';}return;
 }
 if(!window.confirm('Проиграть выбранную мелодию через колонки Школьника сейчас?'))return;
 pending=true;status.textContent='Через колонки Школьника… ожидаем завершения.';
 var timer,controller=new AbortController();
 try{
  timer=setTimeout(function(){controller.abort();},90000);
  var response=await fetch(document.getElementById('router-form').action,{method:'POST',credentials:'same-origin',redirect:'error',signal:controller.signal,body:new URLSearchParams({token:root.dataset.token,id:id})});
  if(!response.ok)throw Error('http');var data=await response.json();
  var messages={completed:'Мелодия завершена.',muted:'Звук отключён кнопкой «Без звука».',busy:'Проигрывание занято. Повторно не запускаем.',unavailable:'Мелодия или аудиовыход недоступны.',invalid:'Неверная мелодия.'};
  status.textContent=messages[data.state] || 'Проигрывание не подтверждено. Проверьте состояние устройства.';
 }catch(_){status.textContent='Ответ не получен. Звук мог начаться: не повторяйте сразу.';}
 finally{clearTimeout(timer);pending=false;}
};
audio.addEventListener('error',function(){status.textContent='Файл недоступен. Проверьте наличие мелодии и вход.';});
window.addEventListener('schoolbell-session-lost',stop);
}());
