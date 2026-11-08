(function(){
'use strict';var root=document.getElementById('schedule-editor'),mute=document.getElementById('quick-mute'),bell=document.getElementById('quick-bell'),status=document.getElementById('quick-status');
var volume=document.getElementById('router-volume'),volumeSave=document.getElementById('volume-save'),volumeStatus=document.getElementById('volume-status'),volumeDirty=false,volumeSteps=[-60,-20,-14,-10,-8,-6,-4,-3,-2,-1,0];
var audioRoute=document.getElementById('audio-route'),audioVolume=document.getElementById('audio-volume'),audioAt=0,displaySample=null;
function audioDraw(){
 if(!audioRoute || !audioVolume)return;
 var age=Date.now()-audioAt;
 var sample=!window.schoolbellSessionBlocked && age<=60000 ? displaySample : null;
 var stale=sample && (!state || age>25000);
 if(window.schoolbellNetworkRender)window.schoolbellNetworkRender(sample && sample.network);
 var a=sample && sample.audio;
 var note=document.getElementById('resource-audio-age');
 if(note)note.textContent=stale?' · последние данные аудио и устройства':'';
 var text='Аудио: нет данных';
 if(a && a.state==='missing')text='Аудио: не обнаружено';
 else if(a && a.state==='ready')text='Аудио: '+(a.controller || 'контроллер неизвестен')+' · '+(a.name || 'карта неизвестна')+(a.model && a.model!==a.name?' ('+a.model+')':'');
 else if(a && a.state==='error')text='Аудио: ошибка проигрывания';
 else if(sample && sample.hardware===false)text='Аудио: устройство не подключено';
 audioRoute.textContent=text.replace(/^Аудио: /,'');audioRoute.title=text;
 var db=sample && sample.volume_db;
 audioVolume.textContent=typeof db==='number' && Number.isInteger(db) && db>=-60 && db<=0?percent(db).replace('%',' %'):'— %';
 var line=document.getElementById('volume-line');
 if(line){var known=audioVolume.textContent!=='— %',value=known?parseInt(audioVolume.textContent,10):0;line.setAttribute('style','--volume-fill:'+value+'%');line.setAttribute('data-tone',known?'normal':'unknown');line.setAttribute('aria-valuetext',known?audioVolume.textContent:'Нет данных');if(known)line.setAttribute('aria-valuenow',String(value));else line.removeAttribute('aria-valuenow');}
 var mode=document.getElementById('device-switch'),ip=document.getElementById('device-ip'),device=sample && sample.device;
 if(mode){mode.textContent=sample && sample.hardware===false?'Переключатель: нет данных':device && device.switch_state==='ready' && ['3G/4G','WISP','AP'].includes(device.position)?'Переключатель: '+device.position:'Переключатель: не определён';mode.title='Физическое положение переключателя, не активный сетевой профиль';}
 if(ip){ip.textContent='IP: '+(device && device.ip || '—');ip.title=device && device.ip || 'Адрес устройства недоступен';}
 var expectation=document.getElementById('media-output-summary');if(expectation)expectation.textContent=text+' '+audioVolume.textContent+(stale?' · последние данные':'');
}
function percent(db){var index=volumeSteps.indexOf(db);return (index>=0?index*10:Math.round(100*Math.pow(10,db/20)))+'%';}
function sliderDraw(){var index=Number(volume.value),db=volumeSteps[index],label=document.getElementById('volume-value'),known=state && Number.isInteger(index) && db!==undefined,text=known?(volumeDirty?String(index*10)+' %':percent(state.volume_db).replace('%',' %')):'— %';if(label)label.textContent=text;volume.setAttribute('aria-valuetext',known?text:'Нет данных');volume.setAttribute('style','--slider-fill:'+(known?100*index/(volumeSteps.length-1):0)+'%');}
var permission=document.getElementById('confirm-play');
window.schoolbellSpeakerCommand=async function(send){
 var confirmed=false;
 if(state && state.confirm_play){
  if(!window.confirm('Проиграть звук через колонки Школьника сейчас?'))return null;
  confirmed=true;
 }
 var result=await send(confirmed);
 // Only this explicit refusal guarantees that the player never started.
 if(!confirmed && result.state==='confirmation_required' && !window.schoolbellSessionBlocked){
  if(!window.confirm('Проиграть звук через колонки Школьника сейчас?'))return null;
  return send(true);
 }
 return result;
};
permission.addEventListener('change',async function(){
 if(!state || busy)return;
 var wanted=permission.checked,started=++epoch;busy=true;draw();
 try{var s=await request(root.dataset.controls,{confirm_play:String(wanted)});
  if(!s.ok)throw Error();if(started===epoch)accept(s);
 }catch(_){if(started===epoch){state=null;volumeStatus.textContent='Не удалось подтвердить сохранение настройки.';}}
 finally{busy=false;draw();if(!state)refresh();}
});
function accept(s){if(window.schoolbellSessionBlocked)return;state=s;displaySample=s;audioAt=Date.now();}
var state=null,busy=false,ringing=false,checking=false,epoch=0,lastCheck=0;
function draw(){audioDraw();permission.disabled=busy || !state || !!window.schoolbellSessionBlocked;if(state && !busy)permission.checked=!!state.confirm_play;if(window.schoolbellSessionBlocked){sliderDraw();volume.disabled=true;volumeSave.disabled=true;mute.disabled=true;bell.disabled=true;mute.dataset.icon="🔊";status.textContent="Войдите для управления звуком. Состояние устройства после выхода не обновляется.";return;}volume.disabled=busy || !state;volumeSave.disabled=busy || !state || !volumeDirty;if(state && !volumeDirty){var gain=state.volume_db===undefined?0:state.volume_db,index=volumeSteps.indexOf(gain);volume.max='10';volume.value=String(index>=0?index:Math.max(0,Math.min(10,Math.round(100*Math.pow(10,gain/20)/10))));}sliderDraw();mute.disabled=busy || !state;bell.disabled=busy || ringing || !state || state.muted || state.playing || state.hardware===false;mute.setAttribute('aria-pressed',String(!!(state && state.muted)));if(state && state.hardware===false)bell.title='Устройство не подключено';mute.dataset.icon=state && state.muted?'🔇':'🔊';mute.title=state?(state.muted?'Разрешить звук устройства':'Отключить звук устройства'):'Без звука: состояние неизвестно';}
async function request(url,body,timeout){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},timeout || 35000);try{var o={credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal};if(body){o.method='POST';o.body=new URLSearchParams(Object.assign({token:root.dataset.token},body));}var r=await fetch(url,o);if(!r.ok)throw Error(r.status===403 || r.status===401?'auth':'http');try{return await r.json();}catch(_){throw Error('response');}}finally{clearTimeout(timer);}}
async function refresh(){if(window.schoolbellSessionBlocked || busy || checking || document.hidden)return;checking=true;var started=epoch;try{if(window.schoolbellInitialReady)await window.schoolbellInitialReady;if(window.schoolbellSessionBlocked || started!==epoch)return;var s=await request(root.dataset.controls);if(!s.ok)throw Error(s.code || 'state');if(started!==epoch)return;accept(s);if(s.muted)status.textContent=s.playing?'Без звука включён. Ожидаем подтверждения остановки проигрывателя…':'Без звука включён. Звук устройства заблокирован.';else if(!ringing)status.textContent=s.playing?'Звонок выполняется. Без звука доступен.':'Звук устройства разрешён. Ручной звонок — один раз, без расписания.';}catch(e){if(started===epoch){state=null;if(e.message==='auth')displaySample=null;var messages={auth:'Войдите в LuCI заново, чтобы управлять звуком.',response:'Ответ сервера не распознан. Обновите страницу или войдите в LuCI.',control_unreadable:'Не удалось прочитать настройки звука на устройстве. Повторяем проверку.',http:'Сервер вернул ошибку запроса состояния звука.'};status.textContent=messages[e.message] || 'Не получен ответ о состоянии звука. Повторяем проверку.';}}finally{checking=false;lastCheck=Date.now();draw();}}
function volumeInput(){if(busy || !state || window.schoolbellSessionBlocked)return;volumeDirty=volumeSteps[Number(volume.value)]!==state.volume_db;draw();}
volume.addEventListener('input',volumeInput);volume.addEventListener('change',volumeInput);
volumeSave.addEventListener('click',async function(){if(busy || !state || !volumeDirty || window.schoolbellSessionBlocked)return;var gain=volumeSteps[Number(volume.value)];if(!Number.isInteger(gain))return;epoch++;busy=true;draw();volumeStatus.textContent='Сохраняем громкость…';try{var s=await request(root.dataset.controls,{volume_db:String(gain)});if(!s.ok)throw Error('volume');accept(s);volumeDirty=false;volumeStatus.textContent='Сохранено: '+percent(s.volume_db)+'. Применится к следующему звонку.';}catch(_){volumeStatus.textContent='Сохранение не подтверждено. Обновите страницу и проверьте громкость.';}finally{busy=false;draw();}});
mute.addEventListener('click',async function(){if(!state || busy)return;epoch++;busy=true;draw();status.textContent='Применяем Без звука…';try{var s=await request(root.dataset.controls,{muted:String(!state.muted)});if(!s.ok)throw Error('mute');accept(s);}catch(_){state=null;status.textContent='Результат Без звука неизвестен. Не считайте звук отключённым до подтверждения.';}finally{busy=false;draw();await refresh();}});
bell.addEventListener('click',async function(){if(!state || state.muted || state.playing || ringing)return;ringing=true;draw();status.textContent='Ручной звонок на устройстве…';try{var r=await window.schoolbellSpeakerCommand(function(ok){return request(root.dataset.manual,ok?{confirmed:'true'}:{},80000);});if(!r){status.textContent='Ручной звонок отменён.';return;}status.textContent=r.ok?'Ручной звонок завершён.':r.state==='muted'?'Звонок остановлен или запрещён Без звука.':'Звонок не подтверждён: '+r.state;}catch(_){status.textContent='Ответ потерян: звонок мог начаться. Не повторяйте сразу.';}finally{ringing=false;draw();}});
window.addEventListener('schoolbell-session-lost',function(){epoch++;state=null;displaySample=null;draw();});window.addEventListener('schoolbell-session-restored',refresh);
window.addEventListener('schoolbell-simulator-update',refresh);
refresh();setInterval(function(){audioDraw();if(ringing || (state && state.playing) || Date.now()-lastCheck>=15000)refresh();},2000);document.addEventListener('visibilitychange',refresh);
}());
