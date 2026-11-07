(function () {
  'use strict';
  var root=document.getElementById('schedule-editor'),panel=document.getElementById('duty-panel');
  var tabs=Array.from(document.querySelectorAll('[data-tab]'));
  function selectTab(name) {
    tabs.forEach(function(b){var active=b.dataset.tab===name;b.setAttribute('aria-selected',String(active));b.tabIndex=active?0:-1;});
    document.querySelectorAll('[data-panel]').forEach(function(p){p.hidden=p.dataset.panel!==name;});
    root.hidden=name==='help' || name==='sound' || name==='media' || name==='journal' || name==='feedback';
    if(name==='journal')loadJournal();
    if(name==='sound'){if(!zoneState)loadZones();readLimit();}
    document.querySelector('.savebar').hidden=false;
    try{sessionStorage.setItem('schoolbell-tab',name);}catch(_){}
  }
  window.addEventListener('schoolbell-open-tab',function(e){if(tabs.some(function(b){return b.dataset.tab===e.detail;}))selectTab(e.detail);});
  document.getElementById('workflow-apply').addEventListener('click',function(){selectTab('sound');document.getElementById('automatic-enable').closest('details').open=true;document.getElementById('automatic-enable').scrollIntoView({block:'center'});});
  var zoneState=null,zoneBusy=false;
  var zoneSelect=document.getElementById('timezone-select'),zoneSave=document.getElementById('timezone-save'),zoneBrowser=document.getElementById('timezone-browser');
  var zoneMessage=document.getElementById('timezone-result');
  function zoneControls(){zoneSelect.disabled=zoneBusy || !zoneState;zoneSave.disabled=zoneBusy || !zoneState || zoneState.pending;zoneBrowser.disabled=zoneBusy || !zoneState;document.getElementById('timezone-reload').disabled=zoneBusy;}
  async function zoneRequest(options){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},15000);
    try{var response=await fetch(root.dataset.timezone,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal},options));if(!response.ok)throw new Error('http');return await response.json();}finally{clearTimeout(timer);}}
  async function loadZones(){
    if(zoneBusy)return;zoneBusy=true;zoneControls();
    try{var value=await zoneRequest();if(!value.ok)throw new Error('zone');zoneState=value;zoneSelect.replaceChildren();
      value.zones.forEach(function(name){var o=document.createElement('option');o.value=name;o.textContent=name.replace(/_/g,' ');zoneSelect.appendChild(o);});
      if(!value.zones.includes(value.zone)){var o=document.createElement('option');o.value=value.zone;o.textContent=value.zone+' (нестандартная настройка)';o.disabled=true;zoneSelect.appendChild(o);}
      zoneSelect.value=value.zone;document.getElementById('timezone-current').textContent='Сохранённый пояс: '+value.zone+(value.runtime_ok?' · применяется':' · применение не подтверждено');
      if(value.pending)zoneMessage.textContent='Есть несохранённые системные настройки. Сначала завершите их изменение; здесь запись заблокирована.';
    }catch(_){zoneState=null;zoneMessage.textContent='Не удалось загрузить часовые пояса. Нажмите «Обновить».';}
    finally{zoneBusy=false;zoneControls();}
  }
  document.querySelectorAll('[data-open-settings]').forEach(function(b){b.addEventListener('click',function(){selectTab('sound');document.getElementById('time-settings').open=true;document.getElementById('panel-sound').scrollIntoView({block:'start'});});});
  document.getElementById('timezone-reload').addEventListener('click',loadZones);
  zoneBrowser.addEventListener('click',function(){var name=Intl.DateTimeFormat().resolvedOptions().timeZone;
    if(zoneState.zones.includes(name)){zoneSelect.value=name;zoneMessage.textContent='Выбран '+name+'. Проверьте место установки и нажмите «Применить».';}else zoneMessage.textContent='Зона браузера '+name+' отсутствует в базе устройства. Выберите город вручную.';});
  zoneSave.addEventListener('click',async function(){
    if(!zoneState || zoneBusy || !window.confirm('Применить '+zoneSelect.value+' на устройстве? Это изменит местное время всех его приложений, но не сами часы.'))return;
    zoneBusy=true;zoneControls();zoneMessage.textContent='Сохраняем часовой пояс…';
    try{var value=await zoneRequest({method:'POST',body:new URLSearchParams({token:root.dataset.token,zone:zoneSelect.value,revision:zoneState.revision})});
      var errors={conflict:'Настройки изменены в другом окне. Обновите данные перед повтором.',pending_changes:'Есть несохранённые системные настройки. Запись не выполнена.',invalid_zone:'Выберите пояс из списка.',apply_failed:'Пояс сохранён, но применение не подтверждено. Обновите данные и повторите применение.',save_uncertain:'Результат сохранения неизвестен. Обновите данные перед повтором.',unavailable:'Настройка недоступна. Проверьте связь и повторите чтение.'};
      zoneMessage.textContent=value.ok?'Часовой пояс применён: '+value.zone+(value.journal_warning?' (журнал недоступен)':''):(errors[value.code] || 'Настройка не выполнена.');
    }catch(_){zoneMessage.textContent='Ответ потерян. Пояс мог сохраниться; проверьте состояние перед повтором.';}
    finally{zoneBusy=false;zoneControls();await loadZones();sample=null;poll();}
  });
  var journalLoaded=false,journalBusy=false,journalEntries=[],journalPage=0,journalWarnings=false,journalErrors=false,journalPageSize=20;
  var limitSelect=document.getElementById('journal-kib'),limitSave=document.getElementById('journal-limit-save'),limitNote=document.getElementById('journal-limit-status');
  var limit=null,limitBusy=false;
  function limitButtons(){
    limitSelect.disabled=limitBusy || limit===null || !!window.schoolbellSessionBlocked;
    limitSave.disabled=limitSelect.disabled || Number(limitSelect.value)===limit;
  }
  function showCapacity(bytes){
    if([16384,32768,65536,131072].includes(bytes))document.getElementById('journal-capacity').textContent=(bytes/1024)+' КиБ';
  }
  async function limitRequest(change){
    var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},15000);
    try{
      var opts={credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal};
      if(change){opts.method='POST';opts.body=new URLSearchParams(change);}
      var url=root.dataset.journal+(change?'':'?action=limit');
      var r=await fetch(url,opts);if(!r.ok)throw Error();
      var v=await r.json();if(!v.ok || ![16384,32768,65536,131072].includes(v.limit_bytes))throw Error(v.code);
      limit=v.limit_bytes/1024;limitSelect.value=String(limit);showCapacity(v.limit_bytes);
    }finally{clearTimeout(timer);}
  }
  async function readLimit(){
    if(limitBusy || window.schoolbellSessionBlocked)return;
    limitBusy=true;limitButtons();
    try{await limitRequest();limitNote.textContent='';}catch(_){limit=null;limitNote.textContent='Не удалось прочитать размер журнала. Откройте настройки повторно.';}
    finally{limitBusy=false;limitButtons();}
  }
  limitSelect.addEventListener('change',limitButtons);
  limitSave.addEventListener('click',async function(){
    if(limitSave.disabled || window.schoolbellSessionBlocked)return;
    var kib=Number(limitSelect.value),shrink=kib<limit;
    if(shrink && !window.confirm('Уменьшить журнал до '+kib+' КиБ? Самые старые записи, которые не поместятся, будут удалены сразу.'))return;
    limitBusy=true;limitButtons();
    try{
      await limitRequest({action:'resize',token:root.dataset.token,kib:String(kib),expected:String(limit),confirmed:String(shrink)});
      limitNote.textContent='Размер журнала сохранён.';
    }catch(_){
      try{await limitRequest();}catch(_){limit=null;}
      limitNote.textContent='Изменение не подтверждено. Проверьте текущий размер.';
    }finally{limitBusy=false;limitButtons();}
  });
  var clearJournal=document.getElementById('journal-clear');
  function clearButton(){clearJournal.disabled=journalBusy || !journalLoaded || !journalEntries.length || !!window.schoolbellSessionBlocked;}
  var actions={device_boot:'Устройство загружено',auto_expired:'Звонок пропущен: истёк срок подачи',auto_audio_unavailable:'Звонок не подан: аудиовыход или проигрыватель недоступен',auto_player_failed:'Звонок не подан: ошибка проигрывателя',system_reset:'Настройки Школьника сброшены; мелодии и журнал сохранены',system_reboot:'Запрошена перезагрузка устройства',system_failed:'Системное действие не подтверждено',clock_set_ok:'Часы установлены из браузера',clock_set_failed:'Установка часов не подтверждена; проверьте фактическое время',clock_confirmed:'Время подтверждено вручную; автозвонки выключены',clock_control_on:'Контроль времени включён; требуется подтверждение часов',clock_control_off:'Контроль времени отключён пользователем',clock_control_failed:'Действие контроля времени не подтверждено',restore_ok:'Резервная копия восстановлена; автозвонки выключены',restore_failed:'Восстановление копии не подтверждено',media_ok:'Мелодия заменена',media_renamed:'Название мелодии изменено',media_failed:'Замена мелодии отклонена',volume_ok:'Громкость устройства сохранена',volume_failed:'Ошибка сохранения громкости',draft_applied:'Применён сохранённый черновик',auto_enabled:'Автозвонки включены',auto_disabled:'Автозвонки отключены',auto_requested:'Автоматический звонок рассмотрен',auto_ok:'Автоматический проигрыватель завершился',auto_skipped:'Автоматический звонок пропущен или остановлен',auto_blocked:'Исполнитель заблокирован: проверьте плашку состояния',mute_on:"Без звука включён",mute_off:"Без звука выключен",mute_failed:"Ошибка изменения Без звука",manual_requested:"Запрошен ручной звонок",timezone_ok:'Часовой пояс применён',timezone_failed:'Не удалось применить часовой пояс',save_ok:'Черновик сохранён',save_failed:'Сохранение отклонено',preview_ok:'Запрошен предпросмотр',preview_failed:'Предпросмотр отклонён',play_requested:'Запрошен звук на устройстве',play_ok:'Проигрыватель завершился успешно',play_failed:'Ошибка проигрывателя',sample_requested:'Передан файл для браузера (не подтверждение звука)',storage_error:'Ошибка хранилища',installed:'Установлен интерфейс schoolbell'};
  function journalTime(e){return e.local_time || new Date(e.time*1000).toISOString().replace('T',' ').replace('.000Z',' UTC');}
  function displayTime(text){return text.replace(/\s+(?:(?:GMT|UTC)[+−-]\d{1,2}(?::?\d{2})?|[+-]\d{2}:?\d{2})$/,'');}
  function journalEvent(e,full){
    var label=actions[e.action] || e.action,bell=e.bell;
    if(!bell)return label;
    var due=full?bell.due:displayTime(bell.due);
    return [label,(bell.kind==='pre'?'Предзвонок':'Основной звонок')+' по расписанию на '+due,bell.plan,bell.schedule].filter(Boolean).join(' · ');
  }
  function journalSource(e){return {user:'Пользователь',module:'Модуль',system:'Система'}[e.source] || e.source;}
  function journalText(){return journalEntries.map(function(e){return '#'+e.seq+' · '+journalTime(e)+' | '+journalSource(e)+' | '+e.level+' | '+journalEvent(e,true);}).join('\n');}
  var sourceChoices=['all','user','system'],sourceFilter='all';
  var dayHeading=new Intl.DateTimeFormat('ru-RU',{year:'numeric',month:'long',day:'numeric',timeZone:'UTC'});
  function localDay(e){
    var local=/^(\d{2})\.(\d{2})\.(\d{4})/.exec(e.local_time || '');
    return local?local[3]+'-'+local[2]+'-'+local[1]:new Date(e.time*1000).toISOString().slice(0,10);
  }
  function renderJournal(){
    var selected=journalEntries.filter(function(e){var sourceMatches=sourceFilter==='all' || e.source===sourceFilter || (sourceFilter==='system' && e.source==='module');
      var levelMatches=(!journalWarnings && !journalErrors) || (journalWarnings && e.level==='warning') || (journalErrors && e.level==='error');
      return sourceMatches && levelMatches;});
    var pages=Math.max(1,Math.ceil(selected.length/journalPageSize));journalPage=Math.max(0,Math.min(journalPage,pages-1));
    var rows=document.getElementById('journal-rows');rows.replaceChildren();
    var previousDay=null;
    selected.slice(journalPage*journalPageSize,(journalPage+1)*journalPageSize).forEach(function(e){
      var day=localDay(e);
      if(day!==previousDay){
        var divider=document.createElement('tr'),heading=document.createElement('th');
        divider.className='journal-day';heading.colSpan=3;
        heading.textContent=dayHeading.format(new Date(day+'T00:00:00Z'));
        divider.appendChild(heading);rows.appendChild(divider);previousDay=day;
      }
      var tr=document.createElement('tr');tr.className='journal-'+e.level;
      ['#'+e.seq+' · '+displayTime(journalTime(e)),journalSource(e),journalEvent(e,false)].forEach(function(text){var td=document.createElement('td');td.textContent=text;tr.appendChild(td);});rows.appendChild(tr);
    });
    var start=journalPage*journalPageSize;
    document.getElementById('journal-page').textContent=selected.length?(start+1)+'–'+Math.min(start+journalPageSize,selected.length)+' из '+selected.length:'0 из 0';
    document.getElementById('journal-first').disabled=document.getElementById('journal-prev').disabled=journalPage===0;
    document.getElementById('journal-last').disabled=document.getElementById('journal-next').disabled=journalPage>=pages-1;
    document.getElementById('journal-warnings').setAttribute('aria-pressed',String(journalWarnings));
    document.getElementById('journal-errors').setAttribute('aria-pressed',String(journalErrors));
    document.getElementById('journal-copy').disabled=!journalEntries.length;clearButton();
  }
  async function loadJournal(){
    if(journalBusy)return;journalBusy=true;clearButton();
    var button=document.getElementById('journal-reload'),status=document.getElementById('journal-status');button.disabled=true;
    var abort=new AbortController(),timer;
    try{
      if(window.schoolbellInitialReady)await window.schoolbellInitialReady;
      timer=setTimeout(function(){abort.abort();},10000);
      var response=await fetch(root.dataset.journal,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});
      if(!response.ok)throw new Error('http');var value=await response.json();if(!value.ok || !Array.isArray(value.entries))throw new Error('journal');
      showCapacity(value.limit_bytes);journalEntries=value.entries.slice().reverse();journalPage=0;renderJournal();journalLoaded=true;
      status.textContent=journalEntries.length?'':'Журнал пока пуст.';
    }catch(_){if(!journalLoaded)document.getElementById('journal-page').textContent='Журнал не загружен';status.textContent=journalLoaded?'Не удалось обновить журнал. Показанные записи могут быть устаревшими.':'Не удалось загрузить журнал. Нажмите ↻ для повторного чтения.';}
    finally{clearTimeout(timer);button.disabled=false;journalBusy=false;clearButton();}
  }
  clearJournal.addEventListener('click',async function(){
    if(clearJournal.disabled || window.schoolbellSessionBlocked || !window.confirm('Удалить все записи журнала, включая скрытые фильтрами? Восстановить их будет нельзя.'))return;
    var reload=document.getElementById('journal-reload'),status=document.getElementById('journal-status');
    journalBusy=true;clearButton();reload.disabled=true;
    var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},15000);
    try{
      var r=await fetch(root.dataset.journal,{method:'POST',credentials:'same-origin',redirect:'error',signal:abort.signal,body:new URLSearchParams({token:root.dataset.token,action:'clear'})});
      if(!r.ok || !(await r.json()).ok)throw Error('clear');
      journalEntries=[];journalPage=0;renderJournal();status.textContent='Журнал очищен.';
    }catch(_){journalLoaded=false;status.textContent='Очистка не подтверждена. Обновите журнал перед повтором.';}
    finally{clearTimeout(timer);journalBusy=false;reload.disabled=false;clearButton();}
  });
  window.addEventListener('schoolbell-session-lost',clearButton);
  window.addEventListener('schoolbell-session-restored',clearButton);
  document.getElementById('journal-reload').addEventListener('click',loadJournal);
  sourceChoices.forEach(function(source){
    document.getElementById('journal-source-'+source).addEventListener('click',function(){
      sourceFilter=source;journalPage=0;
      sourceChoices.forEach(function(key){document.getElementById('journal-source-'+key).setAttribute('aria-pressed',String(key===source));});
      renderJournal();
    });
  });
  document.getElementById('journal-warnings').addEventListener('click',function(){journalWarnings=!journalWarnings;journalPage=0;renderJournal();});
  document.getElementById('journal-errors').addEventListener('click',function(){journalErrors=!journalErrors;journalPage=0;renderJournal();});
  document.getElementById('journal-first').addEventListener('click',function(){journalPage=0;renderJournal();});
  document.getElementById('journal-last').addEventListener('click',function(){journalPage=Infinity;renderJournal();});
  document.getElementById('journal-prev').addEventListener('click',function(){journalPage--;renderJournal();});
  document.getElementById('journal-next').addEventListener('click',function(){journalPage++;renderJournal();});
  document.getElementById('journal-copy').addEventListener('click',async function(){
    var text=journalText(),status=document.getElementById('journal-status');if(!text)return;
    try{
      if(navigator.clipboard && window.isSecureContext){await navigator.clipboard.writeText(text);}
      else{
        var field=document.createElement('textarea'),previous=document.activeElement;field.value=text;field.setAttribute('readonly','');field.style.position='fixed';field.style.opacity='0';document.body.appendChild(field);
        try{field.select();if(!document.execCommand('copy'))throw new Error('copy');}finally{field.remove();if(previous && previous.focus)previous.focus();}
      }
      status.textContent='Скопирована вся загруженная история: '+journalEntries.length+' записей (без ограничения страницей и фильтром).';
    }catch(_){status.textContent='Браузер не разрешил копирование. Попробуйте ещё раз.';}
  });
  renderJournal();
  tabs.forEach(function(b,index){
    b.addEventListener('click',function(){selectTab(b.dataset.tab);});
    b.addEventListener('keydown',function(e){
      var i=index;
      if(e.key==='ArrowRight')i=(i+1)%tabs.length;
      else if(e.key==='ArrowLeft')i=(i+tabs.length-1)%tabs.length;
      else if(e.key==='Home')i=0;
      else if(e.key==='End')i=tabs.length-1;
      else return;
      e.preventDefault();selectTab(tabs[i].dataset.tab);tabs[i].focus();
    });
  });
  var saved=null;try{saved=sessionStorage.getItem('schoolbell-tab');}catch(_){}
  selectTab(tabs.some(function(b){return b.dataset.tab===saved;})?saved:'help');
  try{
    panel.open=localStorage.getItem('schoolbell-status-collapsed')!=='true';}catch(_){}
  panel.addEventListener('toggle',function(){try{localStorage.setItem('schoolbell-status-collapsed',String(!panel.open));}catch(_){} });
  var sample=null,inflight=false;
  var format={weekday:'long',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false};
  function zone(minutes){return 'UTC'+(minutes>=0?'+':'−')+String(Math.floor(Math.abs(minutes)/60)).padStart(2,'0')+':'+String(Math.abs(minutes)%60).padStart(2,'0');}
  function draw() {
    var browser=new Date(),elapsed=sample?performance.now()-sample.received:Infinity;
    document.getElementById('browser-clock').textContent=browser.toLocaleString('ru-RU',format);
    document.getElementById('browser-zone').textContent=Intl.DateTimeFormat().resolvedOptions().timeZone+' · '+zone(-browser.getTimezoneOffset());
    if(window.schoolbellDisplayClock)window.schoolbellDisplayClock(sample&&elapsed<=90000?sample.wall+elapsed:null);
    var status=document.getElementById('clock-status'),sync=document.getElementById('clock-sync');sync.hidden=true;document.getElementById('timezone-hint').hidden=true;
    if(!sample || elapsed>90000){document.getElementById('router-clock').textContent='Время недоступно';status.textContent='Нет свежего ответа устройства. Сравнение часов отключено.';return;}
    document.getElementById('router-clock').textContent=new Date(sample.wall+elapsed).toLocaleString('ru-RU',Object.assign({},format,{timeZone:'UTC'}));
    document.getElementById('router-zone').textContent=(sample.name?sample.name+' · ':'')+zone(sample.offset)+' · получено '+Math.floor(elapsed/1000)+' с назад';
    document.getElementById('timezone-hint').hidden=sample.offset===-browser.getTimezoneOffset();
    var delta=(browser.getTime()-(sample.epoch+elapsed))/1000;
    if(sample.rtt>2000){status.textContent='Медленный ответ устройства: сравнение неточно. Ожидаем следующий опрос.';return;}
    if(Math.abs(delta)>5){status.textContent='Часы устройства '+(delta>0?'отстают':'спешат')+' примерно на '+Math.round(Math.abs(delta))+' с относительно браузера.';sync.hidden=false;}
    else status.textContent='Часы совпадают в пределах 5 с.';
    if(sample.offset!==-browser.getTimezoneOffset())status.textContent+=' Часовые пояса различаются; синхронизация времени не меняет пояс.';
  }
  window.addEventListener('schoolbell-time-changed',function(){sample=null;poll();});
  async function poll() {
    if(inflight || document.hidden)return;
    inflight=true;if(window.schoolbellInitialReady)await window.schoolbellInitialReady;var started=performance.now(),abort=new AbortController(),timer=setTimeout(function(){abort.abort();},10000);
    try{
      var response=await fetch(root.dataset.clock,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});
      if(!response.ok)throw new Error('http');
      var v=await response.json(),received=performance.now(),rtt=received-started;
      if(!v.ok || !Number.isInteger(v.epoch) || !['year','month','day','hour','min','sec'].every(function(k){return Number.isInteger(v[k]);}))throw new Error('clock');
      window.dispatchEvent(new CustomEvent('schoolbell-router-date',{detail:String(v.year).padStart(4,'0')+'-'+String(v.month).padStart(2,'0')+'-'+String(v.day).padStart(2,'0')}));
      var wall=Date.UTC(v.year,v.month-1,v.day,v.hour,v.min,v.sec);
      sample={name:typeof v.zone==='string'?v.zone:null,received:received,epoch:v.epoch*1000+rtt/2,wall:wall+rtt/2,offset:Math.round((wall-v.epoch*1000)/60000),rtt:rtt};
    }catch(_){sample=null;}
    finally{clearTimeout(timer);inflight=false;draw();}
  }
  document.addEventListener('visibilitychange',function(){if(!document.hidden){sample=null;poll();}});
  draw();poll();setInterval(poll,30000);setInterval(draw,1000);
}());

(function(){
 'use strict';
 var summary=document.getElementById('summary-interface');
 if(!summary)return;
 function text(id){return document.getElementById(id).textContent;}
 function selected(id){
  var element=document.getElementById(id);
  return element.selectedIndex>=0?element.options[element.selectedIndex].textContent:'';
 }
 function show(id,parts){
  var element=document.getElementById(id),value=parts.filter(Boolean).join(' · ');
  if(element.textContent!==value)element.textContent=value;
 }
 function draw(){
  if(window.schoolbellSessionBlocked){
   ['summary-interface','summary-time','summary-bells'].forEach(function(id){show(id,['Войдите для просмотра настроек']);});return;
  }
  var limit=document.getElementById('journal-kib');
  show('summary-interface',[
   document.getElementById('header-labels').checked?'Подписи видны':'Подписи скрыты',
   'Автовыход '+selected('session-duration'),
   !limit.disabled?'Журнал '+selected('journal-kib')+(!document.getElementById('journal-limit-save').disabled?' — не применено':''):''
  ]);
  var clock=text('device-clock'),zone=text('router-zone').split(' · получено ')[0];
  show('summary-time',[clock,clock && !clock.includes('—')?zone:'']);
  var editor=window.schoolbellEditor && window.schoolbellEditor.exportSnapshot && window.schoolbellEditor.exportSnapshot();
  if(!editor || !editor.draft){show('summary-bells',['Настройки загружаются…']);return;}
  var draft=editor.draft,annual=draft.mode==='annual';
  var source=annual?(draft.plans || []).find(function(p){return p.id===draft.active_plan;}):
   draft.schedules.find(function(s){return s.id===draft.fixed_schedule;});
  show('summary-bells',[
   (annual?'План':'Расписание')+' «'+(source?source.name:'не выбран')+'»',
   'Громкость '+text('audio-volume'),
   'Предзвонок за '+draft.pre_minutes+' мин',
   editor.dirty?'Есть несохранённые изменения':''
  ]);
 }
 document.getElementById('panel-sound').addEventListener('input',draw);
 document.getElementById('panel-sound').addEventListener('change',draw);
 window.addEventListener('schoolbell-editor-state',draw);
 window.addEventListener('schoolbell-session-lost',draw);
 draw();setInterval(draw,1000);
}());
