(function(){
'use strict';
var root=document.getElementById('schedule-editor'),on=document.getElementById('automatic-enable'),off=document.getElementById('automatic-disable'),message=document.getElementById('automatic-status');
var quick=document.getElementById('quick-automatic'),badge=document.getElementById('quick-automatic-status');
var busy=false,reading=false,sample=null,feedback='',generation=0,pending=null,uncertain=false;
var names={clock_untrusted:'Время не подтверждено: откройте настройки проверки времени',backward_hold:'Часы переведены назад: ожидание прежней границы времени',disabled:'Автозвонки отключены',running:'Автозвонки включены',muted:'Автозвонки · Без звука',playing:'Выполняется звонок',waiting:'Нет свежего подтверждения службы',confirm_clock:'После перезагрузки проверьте часы и включите снова',timezone_changed:'Пояс изменён: проверьте часы и включите снова',clock_invalid:'Недопустимая дата устройства',control_unreadable:'Не читается Без звука',claim_failed:'Ошибка фиксации звонка',nonexistent_time:'В плане есть несуществующее местное время',ambiguous_time:'В плане есть неоднозначное местное время',simultaneous_events:'Несколько звонков назначены на одно время',calendar_invalid:'Ошибка календаря',executor_error:'Ошибка исполнителя',busy:'Звонок пропущен: проигрыватель занят',unavailable:'Исполнитель недоступен',recovery_required:'Проигрыватель требует проверки',expired:'Просроченный звонок пропущен',clock_gap:'Пропуск после скачка часов или задержки'};
async function request(url,body){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},12000);try{var o={credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal};if(body){o.method='POST';o.body=new URLSearchParams(Object.assign({token:root.dataset.token},body));}var response=await fetch(url,o);if(!response.ok)throw Error('HTTP');return await response.json();}finally{clearTimeout(timer);}}
function editor(){return window.schoolbellEditor && window.schoolbellEditor.snapshot();}
function ready(e){return e && e.loaded && !e.dirty && !e.busy && !e.reconcile && e.revision && e.revision!=='empty';}
function confirmed(){var v=sample && performance.now()-sample.at<15000 && sample.value;return v && v.ok!==false && typeof v.enabled==='boolean' && Number.isInteger(v.generation) && v.generation>=0 && v.state!=='waiting' && v.state!=='unavailable' && v.state!=='executor_error'?v:null;}
function header(){
 var v=confirmed(),text,tone='warning',demo=v && v.simulated;
 quick.textContent=v && v.enabled?'⏸ Автозвонки':'▶ Автозвонки';
 quick.title=v && v.enabled?'Выключить автоматические звонки':'Включить ранее применённый план, не черновик';
 if(window.schoolbellSessionBlocked){text='Войдите';tone='warning';}
 else if(busy || pending){text='Ожидаем подтверждения…';}
 else if(!v){text=uncertain?'Исход неизвестен':'Нет свежих данных';tone='danger';}
 else if(!v.enabled){text=v.revision?'Выключены':'План не применён';}
 else if(v.state==='running' || v.state==='playing'){text=v.state==='playing'?'Звонок':'Работают';tone='success';}
 else if(v.state==='muted'){text='Без звука';}
 else{text=names[v.state] || 'Ошибка исполнителя';tone='danger';}
 badge.textContent=(demo?'Демо · ':'')+text;badge.dataset.tone=tone;
 quick.disabled=!!(window.schoolbellSessionBlocked || busy || pending || !v || (v.hardware===false && !v.simulated));
}
function draw(){
 if(pending && performance.now()>=pending.until){pending=null;sample=null;uncertain=true;feedback='Подтверждение не получено. Обновляем состояние, команду не повторяем. ';}
 header();
 window.dispatchEvent(new CustomEvent('schoolbell-diagnostic-state',{detail:{value:confirmed(),pending:!!(busy || pending),uncertain:uncertain,blocked:!!window.schoolbellSessionBlocked}}));
 if(window.schoolbellSessionBlocked){
  on.disabled=true;off.disabled=true;
  ['duty-compact','automatic-mode','workflow-active'].forEach(function(id){document.getElementById(id).textContent='Войдите для просмотра состояния';});
  document.getElementById('automatic-next').textContent='—';document.getElementById('automatic-detail').textContent='Выход не изменяет работу автозвонков.';
  message.textContent='Управление недоступно до входа.';return;
 }

 var fresh=sample && performance.now()-sample.at<15000,v=fresh?sample.value:null;
 window.dispatchEvent(new CustomEvent('schoolbell-clock-state',{detail:v && v.clock_trust || null}));
 var label=v?(names[v.state] || v.state):'Нет свежего ответа исполнителя';
 document.getElementById('duty-compact').textContent=label;
 document.getElementById('automatic-mode').textContent=label+(v && v.mode?' · '+(v.mode==='annual'?'Календарный план':'Ежедневное расписание'):'');
 var remaining=v && v.next?Math.ceil(v.next.utc-v.now-(performance.now()-sample.at)/1000):null;
 document.getElementById('automatic-next').textContent=remaining!==null && remaining>0?(v.state==='muted'?'Будет пропущен · ':'')+Math.floor(remaining/3600)+' ч '+Math.floor(remaining%3600/60)+' мин '+remaining%60+' с':'—';
 document.getElementById('automatic-detail').textContent=v && v.next?'Сегодня '+v.next.time+' · '+(v.next.kind==='pre'?'предзвонок':'основной звонок'):'Сегодня нет следующего звонка или исполнитель не готов.';
 if(!busy)message.textContent=feedback+label;
 var e=editor(),applied=v && v.enabled!==false && v.revision && v.state!=='disabled';
 document.getElementById('workflow-active').textContent=!v?'Активный план: состояние неизвестно':v.hardware===false && !v.simulated?'Активный план: отсутствует в демо':!applied?'Активный план: автозвонки выключены':'Активный план: '+label;
 document.getElementById('workflow-difference').textContent=!e || !e.loaded?'Дождитесь загрузки черновика.':e.reconcile?'Сверьте сохранение перед применением.':e.dirty?'Правки в браузере не входят в активный план. Сначала сохраните черновик.':applied && e.revision!==v.revision?'Сохранённый черновик отличается от активного плана. Для изменения звонков примените его отдельно.':applied?'Сохранённый черновик соответствует активной копии.': 'Сохранение само по себе не включает звонки.';
 on.disabled=busy || !!pending || !ready(e) || !!(v && v.hardware===false && !v.simulated);off.disabled=busy || !!pending || !!(v && v.hardware===false && !v.simulated);
}
async function refresh(){if(window.schoolbellSessionBlocked || reading || busy || document.hidden)return;reading=true;var captured=generation;try{var v=await request(root.dataset.automatic);if(captured===generation){sample={value:v,at:performance.now()};window.dispatchEvent(new CustomEvent('schoolbell-queue-metrics',{detail:v.queue || {available:false}}));window.dispatchEvent(new CustomEvent('schoolbell-system-metrics',{detail:v.cpu || {available:false}}));var current=confirmed();if(current){uncertain=false;if(pending && current.generation>=pending.generation){feedback=current.enabled!==pending.enabled?'Состояние изменено другой командой. ':'';pending=null;}}}}catch(_){if(captured===generation)sample=null;}finally{reading=false;draw();}}
async function change(enabled){
 if(busy)return;
 var e=editor(),locked=false;
 if(enabled && (!ready(e) || !window.schoolbellEditor.lock())){feedback='Сначала сохраните черновик и сверьте результат. ';draw();return;}
 locked=enabled;generation++;busy=true;feedback='';draw();
 try{
 var revision='';if(enabled){var saved=await request(root.dataset.load);
 if(!saved.ok || saved.revision==='empty')throw Error('Сначала сохраните план.');
 if(saved.revision!==e.revision)throw Error('Сохранённый черновик изменён в другом окне. Загрузите его и проверьте перед применением.');
 revision=saved.revision;
 var data=saved.data,mode=data.mode==='annual'?'Календарные планы: '+(data.plans || []).map(function(p){return p.name?p.name+' ['+p.start+' — '+p.end+']':String(p.year);}).join(', '):'Ежедневное расписание · '+((data.schedules || []).find(function(s){return s.id===data.fixed_schedule;}) || {name:'Тихий день'}).name;
 if(!window.confirm('Применить сохранённый черновик и включить автозвонки?\n'+mode+'\nПроверьте дату, время и часовой пояс устройства. Без звука продолжает действовать.'))return;}
 sample=null;
 var result=enabled?await window.schoolbellClockCommand({action:'enable',revision:revision}):await request(root.dataset.automatic,{enabled:'false',revision:''});if(!result.ok)throw Error(result.code==='missing_media'?'Сначала загрузите пользовательские мелодии, выбранные во включённых строках расписаний.':'Не удалось применить. Проверьте сохранение, конфликты времён и хранилище.');
 sample=null;pending={enabled:enabled,generation:result.generation,until:performance.now()+20000};feedback='Запрос принят. Ожидаем подтверждения службы… ';message.textContent=feedback;
 }catch(e){feedback=(e.message || 'Ответ потерян. Проверьте состояние перед повтором.')+' ';message.textContent=feedback;}
 finally{busy=false;if(locked)window.schoolbellEditor.unlock();draw();setTimeout(refresh,1500);}}
async function toggleApplied(){
 var v=confirmed();if(window.schoolbellSessionBlocked || busy || pending || !v)return;
 if(!v.enabled && !v.revision){feedback='Сначала примените сохранённый черновик в настройках. ';draw();var tab=document.getElementById('tab-sound');if(tab)tab.click();document.getElementById('automatic-enable').focus();return;}
 var enable=!v.enabled,captured=++generation;busy=true;feedback='';draw();
 try{
  var result=enable?await window.schoolbellClockCommand({action:'resume',revision:v.revision,generation:String(v.generation)}):await request(root.dataset.automatic,{enabled:'false',revision:''});
  if(captured!==generation || window.schoolbellSessionBlocked)return;
  if(!result.ok)throw Error('Команда не выполнена: '+(result.code || 'ошибка'));
  if(!Number.isInteger(result.generation))throw Error('Нет подтверждения поколения команды');
  sample=null;pending={enabled:enable,generation:result.generation,until:performance.now()+20000};feedback='Запрос принят. Ожидаем подтверждения службы… ';
 }catch(e){if(captured===generation){sample=null;uncertain=true;feedback=(e.message || 'Исход неизвестен')+'. Проверяем состояние без повтора команды. ';}}
 finally{busy=false;draw();refresh();}
}
quick.addEventListener('click',toggleApplied);
window.addEventListener('schoolbell-time-changed',function(){generation++;sample=null;pending=null;draw();refresh();});
window.addEventListener('schoolbell-session-lost' ,function(){generation++;sample=null;pending=null;draw();});
window.addEventListener('schoolbell-session-restored',refresh);
window.addEventListener('schoolbell-diagnostic-refresh',refresh);
window.addEventListener('schoolbell-editor-state',draw);
on.addEventListener('click',function(){return change(true);});off.addEventListener('click',function(){return change(false);});
refresh();setInterval(refresh,5000);setInterval(draw,1000);document.addEventListener('visibilitychange',refresh);
}());
