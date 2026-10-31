(function(factory){
'use strict';
var diagnose=factory();if(typeof module==='object' && module.exports){module.exports=diagnose;return;}
var latest={},panel=document.getElementById('problem-panel'),open=document.getElementById('problem-open'),action=document.getElementById('problem-action');
function draw(){
 var result=diagnose(latest);document.getElementById('problem-summary').textContent=result.title;document.getElementById('problem-explanation').textContent=result.text;
 action.textContent=result.action;action.dataset.target=result.target;
 var e=window.schoolbellEditor && window.schoolbellEditor.snapshot(),v=latest.value;
 // Only diagnostic fields, never session tokens, credentials or full plan contents.
 document.getElementById('problem-details').textContent=JSON.stringify({module:document.getElementById('duty-panel').textContent.match(/5\.[0-9]+\.[0-9]+/)?.[0] || 'unknown',state:v && v.state || 'unknown',generation:v && v.generation,clock_reason:v && v.clock_trust && v.clock_trust.reason,applied_revision:v && v.revision,draft_revision:e && e.revision,unsaved_changes:!!(e && e.dirty),demo:!!(v && v.simulated)},null,2);
}
function close(){panel.hidden=true;open.setAttribute('aria-expanded','false');open.focus();}
open.addEventListener('click',function(){panel.hidden=!panel.hidden;open.setAttribute('aria-expanded',String(!panel.hidden));if(!panel.hidden){draw();panel.scrollIntoView({block:'nearest'});}});
document.getElementById('problem-close').addEventListener('click',close);
document.getElementById('problem-refresh').addEventListener('click',function(){window.dispatchEvent(new CustomEvent('schoolbell-diagnostic-refresh'));});
function go(id){var target=document.getElementById(id);if(target){target.click();target.focus();}}
action.addEventListener('click',function(){go(action.dataset.target);});
document.getElementById('problem-journal').addEventListener('click',function(){go('tab-journal');});
window.addEventListener('schoolbell-diagnostic-state',function(e){latest=e.detail || {};if(!panel.hidden)draw();});
window.addEventListener('schoolbell-session-lost',function(){latest={blocked:true};if(!panel.hidden)draw();});
window.addEventListener('schoolbell-editor-state',function(){if(!panel.hidden)draw();});
})(function(){
'use strict';
return function(s){
 s=s || {};var v=s.value;
 function result(title,text,action,target){return {title:title,text:text,action:action || 'Открыть настройки',target:target || 'tab-sound'};}
 if(s.blocked)return result('Нужно войти','Сеанс управления завершён или не подтверждён. Войдите обычным способом; несохранённые правки остаются в этой вкладке. Выход не останавливает уже включённый план.','Войти','session-login');
 if(s.pending)return result('Операция ещё проверяется','Дождитесь результата. Повторное чтение безопасно; команда включения, сохранения или восстановления не повторяется.');
 if(!v)return result(s.uncertain?'Результат команды пока неизвестен':'Нет свежих данных о работе модуля','Не удалось получить актуальное состояние. Это само по себе не доказывает неисправность сети или Wi-Fi. Повторите чтение; если состояние не появится, откройте журнал или обратную связь.','Открыть обратную связь','tab-feedback');
 if(v.clock_trust && v.clock_trust.enforced && v.clock_trust.state!=='confirmed')return result('Требуется проверка времени',v.clock_trust.reason==='observation_gap'?'Модуль слишком долго не наблюдал часы. Это не доказывает неверную дату. В настройках сверьте дату и подтвердите её. Если блокировка повторяется, обратитесь с техническими подробностями.':'В настройках сверьте дату и часовой пояс, затем подтвердите время. Подтверждение не переводит часы и не включает звонки.');
 if(v.state==='muted')return result('Включён режим «Без звука»','План включён, но подача звука запрещена. Чтобы вернуть звук, используйте кнопку «Без звука» в шапке; это отдельное действие.');
 if(v.state==='running' || v.state==='playing')return result('По свежим данным модуль работает',v.state==='playing'?'Исполнитель сообщает о воспроизведении; слышимость колонок проверяется отдельно.':'План включён. Отсутствие ближайшего звонка может означать тихий день. Проверьте назначения и предпросмотр.','Открыть предпросмотр','tab-preview');
 if(v.state==='disabled')return result(v.revision?'Автозвонки выключены':'План ещё не применён',v.revision?'Это штатное состояние. Кнопка «Автозвонки» в шапке включает ранее применённую копию; черновик не применяется автоматически.':'Сохраните черновик и отдельно примените его в настройках. Диагностика не делает это за вас.');
 if(/media|recovery|control_unreadable/.test(v.state))return result('Нужна проверка звука или файлов','Откройте мелодии и проверьте список. Не удаляйте файлы блокировок вручную. Если ошибка сохраняется, посмотрите журнал.','Открыть мелодии','tab-media');
 return result('Исполнитель требует внимания','Откройте журнал и технические подробности. Автоматического сброса защиты, удаления блокировок и повторного запуска здесь нет.','Открыть журнал','tab-journal');
};
});
