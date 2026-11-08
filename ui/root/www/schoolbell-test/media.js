(function(){
'use strict';var title=document.getElementById('media-title');var root=document.getElementById('schedule-editor'),rows=document.getElementById('media-rows'),slot=document.getElementById('media-slot'),file=document.getElementById('media-file'),send=document.getElementById('media-upload'),reload=document.getElementById('media-refresh'),listen=document.getElementById('media-listen'),audio=document.getElementById('media-audio'),message=document.getElementById('media-status'),state=null,busy=false,playGeneration=0;
function storage(s){var bar=document.getElementById('storage-bar'),text=document.getElementById('storage-text'),reserve=document.getElementById('storage-reserve'),policy=document.getElementById('storage-policy');bar.hidden=!s;if(!s){delete bar.dataset.level;text.textContent='Данные о месте сейчас недоступны.';reserve.textContent='';policy.textContent='';return;}var mb=function(k){return (k/1024).toFixed(2)+' МиБ';};bar.value=s.total_kib>0?Math.min(100,100*s.used_kib/s.total_kib):0;bar.dataset.level=bar.value>90?'critical':bar.value>75?'warning':'normal';bar.setAttribute('aria-label','Занято места'+(bar.value>90?' — более 90%, критическое заполнение':bar.value>75?' — более 75%, мало свободного места':''));text.textContent=(bar.value>90?'Критическое заполнение. ':bar.value>75?'Мало свободного места. ':'')+'Занято '+mb(s.used_kib)+' · свободно '+mb(s.free_kib)+' из '+mb(s.total_kib);reserve.textContent='Из занятого места: пользовательские мелодии и сохранённые копии — '+mb(s.media_kib)+'.';policy.textContent='Условия загрузки: не менее '+mb(s.reserve_kib)+' должно оставаться свободным для системы. Это запас свободного места, а не занятое место. При замене мелодии дополнительно требуется место для временной копии файла и служебных данных.';}
function playable(v){return v && v.source!=='empty';}
function stopAudio(){playGeneration++;audio.pause();audio.removeAttribute('src');audio.load();}
function play(id){if(busy || !state)return;var v=state.slots.find(function(x){return x.id===id;});if(!playable(v))return;stopAudio();var generation=playGeneration;audio.src=state.demo?root.dataset.sample.replace(/test\.mp3$/,encodeURIComponent(id)+'.mp3'):root.dataset.sample+'?id='+encodeURIComponent(id);message.textContent='🔊 В браузере: '+(v.title || v.name)+'. Колонки устройства не используются.';audio.play().catch(function(){if(generation===playGeneration)message.textContent='Не удалось прослушать файл. Обновите список.';});}
function deletionReason(v){
 if(!v || v.source!=='user')return 'Штатная мелодия';
 if(v.in_use!==false)return 'Используется в сохранённых настройках или применённом плане';
 var editor=window.schoolbellEditor, snapshot=editor&&editor.exportSnapshot&&editor.exportSnapshot();
 if(!snapshot || !snapshot.draft || snapshot.dirty || snapshot.busy || snapshot.reconcile)return 'Сначала сохраните изменения расписаний и настроек';
 var d=snapshot.draft;
 if(d.pre_media===v.id || d.manual_media===v.id || d.schedules.some(function(s){return s.rows.some(function(r){return r.media===v.id;});}))return 'Мелодия используется';
 return '';
}
function openEditor(id){
 if(busy || !state || state.demo || window.schoolbellSessionBlocked)return;
 var v=state.slots.find(function(v){return v.id===id;});
 if(id!=='new' && (!v || v.source!=='user'))return;
 if(slot.value!==id){
  var previous=state.slots.find(function(v){return v.id===slot.value;});
  var originalTitle=previous?(previous.title || previous.name):'';
  if((file.files.length || title.value!==originalTitle) && !confirm('Перейти к другой мелодии? Введённое название и выбранный файл в форме будут сброшены.'))return;
  slot.value=id;file.value='';title.value=v?(v.title || v.name):'';
 }
 var form=document.getElementById('media-edit-form');form.open=true;draw();form.scrollIntoView({block:'nearest'});title.focus();
}
function draw(){var selected=state&&state.slots.find(function(v){return v.id===slot.value;});var rename=document.getElementById('media-rename');rename.hidden=slot.value==='new';rename.disabled=busy || !state || state.demo || !!window.schoolbellSessionBlocked || !selected || selected.source!=='user' || !!file.files.length || !title.value.trim() || title.value.trim()===(selected.title || selected.name);document.getElementById('media-add').disabled=busy || !state || state.demo || !!window.schoolbellSessionBlocked;send.textContent='💾';send.title=slot.value==='new'?'Загрузить мелодию':'Загрузить и заменить';send.setAttribute('aria-label',send.title);send.disabled=busy || !state || state.demo || !file.files.length || !title.value.trim();reload.disabled=busy;listen.disabled=busy || !state || !state.slots.some(function(v){return v.id===slot.value && playable(v);});slot.disabled=busy;title.disabled=busy;file.disabled=busy || !!(state && state.demo);rows.querySelectorAll('button').forEach(function(b){var v=state&&state.slots.find(function(v){return v.id===b.dataset.id;});if(b.dataset.replace==='true'){b.disabled=busy || !state || state.demo || !!window.schoolbellSessionBlocked || !v || v.source!=='user';}else if(b.dataset.delete==='true'){var why=deletionReason(v);b.disabled=busy || !state || state.demo || !!why;b.title=why || 'Удалить мелодию';}else b.disabled=busy || !state || (b.dataset.hardware==='true' && state.demo) || !playable(v);});}
var page=0,pageSize=10,prev=document.getElementById('media-prev'),next=document.getElementById('media-next'),range=document.getElementById('media-range'),first=document.getElementById('media-first'),last=document.getElementById('media-last');
function renderPage(){
 var total=state.slots.length;
 page=Math.max(0,Math.min(page,Math.ceil(total/pageSize)-1));
 var start=page*pageSize;
 range.textContent=total?(start+1)+'–'+Math.min(total,start+pageSize)+' из '+total:'0 из 0';
 first.disabled=prev.disabled=page===0;
 last.disabled=next.disabled=start+pageSize>=total;
 rows.replaceChildren();var group=null;state.slots.slice(start,start+pageSize).forEach(function(v,index){var currentGroup=v.source==='builtin'?'Штатные':v.source==='user'||v.source==='empty'?'Пользовательские':'Штатные';if(currentGroup!==group){var divider=document.createElement('tr'),heading=document.createElement('th');divider.className='media-group';heading.colSpan=6;heading.setAttribute('scope','rowgroup');heading.textContent=currentGroup;divider.appendChild(heading);rows.appendChild(divider);group=currentGroup;}var tr=document.createElement('tr');[String(start+index+1),v.title || v.name,v.source==='empty'?'—':v.name,v.source==='empty'?'—':Math.ceil(v.size_bytes/1024)+' КиБ',v.source==='user'?'Загружена':v.source==='empty'?'Пустой слот — загрузите MP3':'Штатная · защищена'].forEach(function(t){var td=document.createElement('td');td.textContent=t;tr.appendChild(td);});var td=document.createElement('td'),actions=document.createElement('div');actions.className='row-actions media-actions';if(v.source==='user'){var replace=document.createElement('button');replace.type='button';replace.className='row-edit';replace.textContent='*';replace.dataset.id=v.id;replace.dataset.replace='true';replace.title='Изменить мелодию';replace.setAttribute('aria-label','Изменить мелодию '+(v.title || v.name));replace.addEventListener('click',function(){openEditor(v.id);});actions.appendChild(replace);}[false,true].forEach(function(hardware){var button=document.createElement('button');button.type='button';button.dataset.id=v.id;button.dataset.hardware=hardware?'true':'false';button.className=hardware?'media-device':'media-browser';button.textContent=hardware?'🔔':'🔊';button.title=hardware?'Проиграть через Школьника':'Проиграть в браузере';button.setAttribute('aria-label',button.title+': '+(v.title || v.name));button.addEventListener('click',function(){if(hardware){if(window.schoolbellRowPreview)window.schoolbellRowPreview(v.id,true,message);}else play(v.id);});actions.appendChild(button);});if(v.source==='user'){var del=document.createElement('button');del.type='button';del.className='icon-delete';del.textContent='×';del.dataset.id=v.id;del.dataset.delete='true';del.setAttribute('aria-label','Удалить мелодию '+(v.title || v.name));del.addEventListener('click',function(){return remove(v);});actions.appendChild(del);}td.appendChild(actions);tr.appendChild(td);rows.appendChild(tr);});
}
function turnPage(step){if(state){page+=step;renderPage();draw();}}
first.addEventListener('click',function(){turnPage(-Infinity);});
last.addEventListener('click',function(){turnPage(Infinity);});
prev.addEventListener('click',function(){turnPage(-1);});
next.addEventListener('click',function(){turnPage(1);});
function render(s){state=s;window.dispatchEvent(new CustomEvent('schoolbell-media',{detail:s.slots}));storage(s.storage);renderPage();var selected=slot.value;slot.replaceChildren();var add=document.createElement('option');add.value='new';add.textContent='＋ Добавить мелодию';slot.appendChild(add);s.slots.filter(function(v){return v.source==='user';}).forEach(function(v){var o=document.createElement('option');o.value=v.id;o.textContent='Изменить: '+(v.title || v.name);slot.appendChild(o);});slot.value=s.slots.some(function(v){return v.id===selected && v.source==='user';})?selected:'new';}
async function refreshList(){for(var attempt=0;attempt<4;attempt++){var s=await request(root.dataset.media);if(s.ok){render(s);return;}if(s.code!=='busy' || attempt===3)throw Error(s.code);message.textContent='Медиатека занята другой операцией. Повторяем чтение списка…';await new Promise(function(resolve){setTimeout(resolve,[200,500,1000][attempt]);});}}
function unavailable(keepRows){state=null;first.disabled=last.disabled=prev.disabled=next.disabled=true;if(!keepRows){rows.replaceChildren();range.textContent='';}storage(null);}
async function request(url,options){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},120000);try{var r=await fetch(url,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal},options));if(!r.ok)throw Error('HTTP '+r.status);return await r.json();}finally{clearTimeout(timer);}}
async function load(){if(busy)return;busy=true;stopAudio();draw();message.textContent='Читаем список мелодий…';try{await refreshList();message.textContent=state.demo?'Прослушивание — в браузере. Для загрузки подключите устройство.':'Список обновлён. Замена не включает автозвонки.';}catch(e){unavailable(e.message==='busy');message.textContent=e.message==='busy'?'Медиатека пока занята проигрыванием или другой операцией. Предыдущий список, если он виден, не подтверждён. Дождитесь завершения и нажмите «Обновить список».':'Не удалось прочитать медиатеку ('+e.message+'). Нажмите «Обновить список». Это не подтверждает повреждение файлов.';}finally{busy=false;draw();}}
async function remove(v){
 if(busy || !state || state.demo || deletionReason(v))return;
 if(!confirm('Удалить мелодию «'+(v.title || v.name)+'»?'))return;
 var editor=window.schoolbellEditor;
 if(!editor || !editor.lock({allowEmpty:true})){message.textContent='Сначала сохраните изменения расписаний и настроек.';return;}
 var random=new Uint8Array(16);crypto.getRandomValues(random);var op=Array.from(random,function(x){return x.toString(16).padStart(2,'0');}).join('');
 var url=root.dataset.media+'?'+new URLSearchParams({action:'delete',id:v.id,generation:String(state.generation),operation:op}).toString();
 busy=true;stopAudio();draw();var outcome='';
 try{var r=await request(url,{method:'POST',headers:{Authorization:'Bearer '+root.dataset.token},body:''});if(!r.ok)throw Error(({in_use:'мелодия используется в настройках или применённом плане',automatic_enabled:'сначала отключите автозвонки',conflict:'список изменился',busy:'устройство занято'})[r.code] || r.code);outcome='Мелодия удалена.';}
 catch(e){outcome='Удаление не подтверждено ('+e.message+'). Проверьте обновлённый список перед повтором.';}
 try{await refreshList();message.textContent=outcome;}catch(e){unavailable(true);message.textContent=outcome+' Не удалось прочитать список; нажмите «Обновить список».';}
 finally{busy=false;editor.unlock();draw();}
}
window.addEventListener('schoolbell-editor-state',draw);
window.addEventListener('schoolbell-session-lost',draw);window.addEventListener('schoolbell-session-restored',draw);
title.addEventListener('input',draw);
document.getElementById('media-rename').addEventListener('click',async function(){
 if(busy || !state || state.demo || window.schoolbellSessionBlocked || file.files.length)return;
 var v=state.slots.find(function(v){return v.id===slot.value;}),name=title.value.trim();
 if(!v || v.source!=='user' || !name)return;
 if(new TextEncoder().encode(name).length>96 || /[\x00-\x1f\x7f]/.test(name)){message.textContent='Укажите название до 96 байт без управляющих символов.';return;}
 if(name===(v.title || v.name))return;
 var random=new Uint8Array(16);crypto.getRandomValues(random);var op=Array.from(random,function(v){return v.toString(16).padStart(2,'0');}).join('');
 var url=root.dataset.media+'?'+new URLSearchParams({action:'rename',id:v.id,title:name,generation:String(state.generation),operation:op}).toString().replace(/\+/g,'%20');
 busy=true;draw();var outcome='';
 try{var r=await request(url,{method:'POST',headers:{Authorization:'Bearer '+root.dataset.token},body:''});if(!r.ok)throw Error(({automatic_enabled:'сначала отключите автозвонки',conflict:'список изменился',busy:'устройство занято'})[r.code] || r.code);outcome='Название сохранено.';}
 catch(e){outcome='Сохранение названия не подтверждено ('+e.message+').';try{var known=await request(root.dataset.media+'?operation='+op);if(known.ok && known.state==='retained')outcome='Название сохранено: операция подтверждена.';}catch(_){} }
 try{await refreshList();message.textContent=outcome;}catch(e){unavailable(true);message.textContent=outcome+' Не удалось обновить список. Повторно не сохраняйте, сначала нажмите «Обновить список».';}
 finally{busy=false;draw();}
});
document.getElementById('media-add').addEventListener('click',function(){openEditor('new');});
slot.addEventListener('change',function(){var v=state&&state.slots.find(function(v){return v.id===slot.value;});title.value=v?(v.title || v.name):'';draw();});file.addEventListener('change',function(){if(slot.value==='new' && !title.value && file.files.length)title.value=file.files[0].name.replace(/\.mp3$/i,'');draw();});reload.addEventListener('click',load);document.getElementById('tab-media').addEventListener('click',load);
listen.addEventListener('click',function(){play(slot.value);});
send.addEventListener('click',async function(){if(busy || !state || state.demo || !file.files.length)return;var f=file.files[0];if(!title.value.trim() || new TextEncoder().encode(title.value.trim()).length>96){message.textContent='Укажите название до 96 байт.';return;}if(!/\.mp3$/i.test(f.name)){message.textContent='Выберите файл MP3. Другие форматы не поддерживаются.';return;}if(!f.size || f.size>65536 || new TextEncoder().encode(f.name).length>96){message.textContent='Нужен непустой файл до 64 КиБ с именем до 96 байт.';return;}if(!confirm((slot.value==='new'?'Добавить мелодию «'+title.value.trim()+'»?':'Заменить выбранную мелодию во всех расписаниях?')+' Автозвонки должны быть отключены.'))return;
var random=new Uint8Array(16);crypto.getRandomValues(random);var op=Array.from(random,function(v){return v.toString(16).padStart(2,'0');}).join('');var url=root.dataset.media+'?'+new URLSearchParams({id:slot.value,name:f.name,title:title.value.trim(),generation:String(state.generation),operation:op}).toString().replace(/\+/g,'%20');busy=true;stopAudio();draw();var confirmed=false;message.textContent='Загрузка и проверка без звука…';
try{var s=await request(url,{method:'POST',headers:{'Content-Type':'application/octet-stream','Authorization':'Bearer '+root.dataset.token},body:f});if(!s.ok)throw Error(({automatic_enabled:'сначала отключите автозвонки',space:'недостаточно свободного места',conflict:'список изменён в другой вкладке',busy:'проигрыватель или загрузка заняты',rejected:'файл не прошёл проверку или загрузка оборвалась'})[s.code] || s.code);file.value='';confirmed=true;}catch(e){unavailable(true);var failure=e.message;message.textContent='Замена не подтверждена ('+failure+'). Проверяем операцию…';try{var known=await request(root.dataset.media+'?operation='+op);confirmed=known.ok && known.state==='retained';if(confirmed)file.value='';message.textContent=confirmed?'Сохранённая операция найдена.':'Замена не подтверждена ('+failure+'). Операция не найдена: '+op+'.';}catch(_){message.textContent='Замена не подтверждена ('+failure+'). Проверка операции недоступна. Операция '+op+'.';}if(!confirmed){var outcome=message.textContent;try{await refreshList();message.textContent=outcome+' Текущий список прочитан; сравните название и ревизию перед повтором.';}catch(readError){unavailable(true);message.textContent=outcome+' Список не прочитан ('+readError.message+'). Прежние строки не подтверждены; нажмите «Обновить список».';}}}finally{if(confirmed){try{await refreshList();message.textContent='Мелодия сохранена, список обновлён. Автозвонки не включались.';}catch(e){unavailable();message.textContent='Мелодия сохранена, но список не прочитан ('+e.message+'). Нажмите «Обновить список»; повторно загружать файл не нужно.';}}busy=false;draw();}});
// Give initial editor data priority, but never starve status controls on a failed read.
async function startupWait(p){var timer;try{await Promise.race([Promise.resolve(p),new Promise(function(resolve){timer=setTimeout(resolve,1500);})]);}finally{clearTimeout(timer);}}
window.schoolbellInitialMedia=startupWait(window.schoolbellInitialDraft).then(load);
window.schoolbellInitialReady=startupWait(window.schoolbellInitialMedia);
})();
