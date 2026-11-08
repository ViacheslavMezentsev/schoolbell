(function () {
  'use strict';
  var root=document.getElementById('schedule-editor');
  var fields=document.getElementById('schedule-fields');
  var select=document.getElementById('schedule-select');
  var result=document.getElementById('schedule-result');
  var save=document.getElementById('schedule-save');
  var reload=document.getElementById('schedule-reload');
  var badge=document.getElementById('draft-state');
  var name=document.getElementById('schedule-name');
  var rows=document.getElementById('schedule-rows');
  var draft=null, revision=null, selected=null, dirty=false, busy=false, reconcile=false, activationLock=false;
  var handoffReady=false, sessionEpoch=0;
  var handoffKey="schoolbell-editor-handoff-v1";
  var mediaNames={test:'Тестовый звонок','0':'[Короткая] Время','1':'Шутка Баха','2':'Гостья из будущего','3':'Князь Игорь','4':'Усатый нянь'};
  function mediaLabel(id){return mediaNames[id] || 'Пользовательская мелодия';}
  function mediaOptions(box,value){box.replaceChildren();var ids=mediaIds.slice();if(value && ids.indexOf(value)<0)ids.push(value);ids.forEach(function(id){box.appendChild(textOption(id,mediaLabel(id)));});box.value=value;}
  window.addEventListener('schoolbell-media',function(e){mediaIds=e.detail.filter(function(v){return v.source!=='empty';}).map(function(v){return v.id;});e.detail.forEach(function(v){mediaNames[v.id]=v.title || v.name;});document.querySelectorAll('#preview-events [data-media]').forEach(function(label){label.textContent=mediaLabel(label.dataset.media);});document.querySelectorAll('#manual-media,#pre-media,#schedule-rows select').forEach(function(box){mediaOptions(box,box.value);});});
  var mediaIds=["test","0","1","2","3","4"];
  if(root.dataset.load.indexOf('demo-api')>=0)mediaIds=['test','0','1','2','3','4'];
  var counter=0;
  var R=window.RangePlans,monthPage=0, brush='view', painting=false,planId=null,formPending=false,newPlan=false,copyPlan=null;
  var routerDate=null;

  var monthNames=['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
  // Schoolbell specification 4.6.64: built-in IDs and order are stable.
  var colorCssNames=['royalblue','green','firebrick','rebeccapurple','slategray','yellowgreen','maroon','mediumorchid',
    'darkturquoise','lightgreen','saddlebrown','darksalmon','skyblue','gold','chocolate','plum'];
  var colors=['#4169e1','#008000','#b22222','#663399','#708090','#9acd32','#800000','#ba55d3',
    '#00ced1','#90ee90','#8b4513','#e9967a','#87ceeb','#ffd700','#d2691e','#dda0dd'];
  var colorNames=['Синий','Зелёный','Красный','Фиолетовый','Серо-синий','Салатовый','Бордовый','Орхидейный',
    'Бирюзовый','Светло-зелёный','Коричневый','Лососевый','Голубой','Золотистый','Шоколадный','Светло-сиреневый'];
  function ink(color){var rgb=color.slice(1).match(/../g).map(function(v){var n=parseInt(v,16)/255;return n<=0.04045?n/12.92:Math.pow((n+0.055)/1.055,2.4);});
    var l=rgb[0]*0.2126+rgb[1]*0.7152+rgb[2]*0.0722;return l>0.179?'#000000':'#ffffff';}
  function colorOf(id){var item=draft.schedules.find(function(s){return s.id===id;});return item?colors[item.color-1]:'';}
  function nextColor(){for(var i=1;i<=16;i++)if(!draft.schedules.some(function(s){return s.color===i;}))return i;return draft.schedules.length%16+1;}
  function renderColors(){
    var currentSchedule=current(),palette=document.getElementById('schedule-colors');palette.replaceChildren();
    if(!currentSchedule)return;
    colors.forEach(function(color,i){var button=document.createElement('button');button.type='button';button.textContent=i+1;
      button.style.background=color;button.style.color=ink(color);button.title=colorNames[i]+' ('+colorCssNames[i]+')';button.setAttribute('aria-label','Цвет '+(i+1)+': '+button.title);
      button.setAttribute('aria-pressed',String(currentSchedule.color===i+1));
      button.addEventListener('click',function(){currentSchedule.color=i+1;changed();render();});palette.appendChild(button);
    });
    select.style.borderLeft='10px solid '+colorOf(currentSchedule.id);
    name.style.borderLeft='10px solid '+colorOf(currentSchedule.id);
  }
  function dates(y) {
    var out=[],leap=y%4===0 && (y%100!==0 || y%400===0);
    var lengths=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31];
    lengths.forEach(function(n,m){for(var d=1;d<=n;d++)out.push(String(y).padStart(4,'0')+'-'+String(m+1).padStart(2,'0')+'-'+String(d).padStart(2,'0'));});
    return out;
  }
  function weekday(date) {
    var a=date.split('-').map(Number),d=new Date(0);
    d.setUTCFullYear(a[0],a[1]-1,a[2]); d.setUTCHours(0,0,0,0);
    return (d.getUTCDay()+6)%7;
  }
  function plan() {return (draft.plans || []).find(function(p){return p.id===planId;});}
  function planDates(){var p=plan();return p?R.dates(p.start,p.end):[];}
  function formStatus(t){document.getElementById('plan-form-status').textContent=t;}
  function fillPlan(){var p=plan();formPending=false;newPlan=false;copyPlan=null;['name','start','end'].forEach(function(k){document.getElementById('plan-'+k).value=p?p[k]:'';});if(p){monthPage=0;document.getElementById('range-first').value=p.start;document.getElementById('range-last').value=p.end;}else monthPage=0;}
  function leaveForm(){return !formPending || window.confirm('Отменить неприменённый ввод названия и дат?');}
  function assigned(p,i) {var c=p?p.days.charAt(i):'.';return c==='.'?'quiet':p.schedule_ids[c.charCodeAt(0)-65];}
  function prune(p) {
    var ids=[],out='';
    for(var i=0;i<p.days.length;i++) {
      var value=assigned(p,i);
      if(value==='quiet') {out+='.';continue;}
      var slot=ids.indexOf(value);if(slot<0){slot=ids.length;ids.push(value);}
      out+=String.fromCharCode(65+slot);
    }
    p.schedule_ids=ids;p.days=out;
  }
  function scheduleName(id) {var item=draft.schedules.find(function(s){return s.id===id;});return item?item.name:'Тихий день';}
  function paint(indices, incremental) {
    if(brush==='view' || busy || activationLock || formPending)return;
    var p=plan(),value=brush;if(!p)return;
    prune(p);
    var slot=value==='quiet'?-1:p.schedule_ids.indexOf(value);
    if(value!=='quiet' && slot<0){slot=p.schedule_ids.length;p.schedule_ids.push(value);}
    var code=slot<0?'.':String.fromCharCode(65+slot),chars=p.days.split(''),didChange=false;
    indices.forEach(function(i){if(chars[i]!==code){chars[i]=code;didChange=true;}});
    p.days=chars.join('');prune(p);
    if(didChange){changed();if(incremental)refreshDays();else renderAnnual();}
  }
  function refreshDays() {
    var p=plan();
    document.querySelectorAll('.calendar-day').forEach(function(b){
      var sid=assigned(p,Number(b.dataset.index));
      b.title=b.dataset.date+' · '+scheduleName(sid);b.setAttribute('aria-label',b.title);
      b.style.background=sid==='quiet'?'':colorOf(sid);
      b.style.color=sid==='quiet'?'':ink(colorOf(sid));
    });
    document.getElementById('plan-status').textContent=(p?p.name:'План ещё не создан')+': назначено '+(p?p.days.replace(/\./g,'').length:0)+' из '+(p?p.days.length:0)+' дней. Остальные тихие.';
  }

  function markToday(button){
    if(routerDate && button.dataset.date===routerDate.date)button.setAttribute('aria-current','date');
    else button.removeAttribute('aria-current');
  }
  window.addEventListener('schoolbell-router-date',function(event){
    var previous=routerDate;
    routerDate={date:event.detail,at:performance.now()};
    if(previous && previous.date===event.detail)return;
    document.querySelectorAll('.calendar-day').forEach(markToday);
  });
  function chooseBrush(value) {brush=value;renderAnnual();}
  var appliedPlanId=null,appliedFixedId=null,running=false,savedDraft=null;
  function protectedEdit(){
    if(!running || !savedDraft || !draft || !dirty)return '';
    var key=appliedFixedId?'schedules':'plans',id=appliedFixedId || appliedPlanId;
    var before=savedDraft[key].find(x=>x.id===id),after=draft[key].find(x=>x.id===id);
    return before && canonical(before)!==canonical(after)?'Чтобы изменить «'+before.name+'», остановите автозвонки.':'';
  }
  function deletionReason(){
    if(planId && planId===appliedPlanId)return 'Этот план применён. Чтобы удалить его, сначала примените другой план или ежедневное расписание.';
    if(planId && draft && draft.mode==='annual' && planId===draft.active_plan)return 'Этот план выбран в Настройках. Сначала измените выбор.';
    return '';
  }
  function updateScheduleDelete(){
    var button=document.getElementById('schedule-delete'),inUse=selected &&  (selected===appliedFixedId || draft && draft.mode==='fixed' && selected===draft.fixed_schedule);
    button.disabled=!current() || !!inUse;
    button.title=inUse?'Расписание применено. Сначала примените другой выбор.':'Удалить расписание';
  }
  function updateDelete(){
    var button=document.getElementById('year-clear'),reason=deletionReason();
    button.disabled=!plan() || !!reason;
    button.title=reason || 'Удалить выбранный план';
    document.getElementById('plan-delete-hint').textContent=reason;
  }
  window.addEventListener('schoolbell-diagnostic-state',function(event){
    var v=event.detail && event.detail.value;
    if(v){var changedStatus=running!==v.enabled || appliedPlanId!==(v.context && v.context.plan_id) || appliedFixedId!==(v.context && v.context.fixed_id);running=v.enabled;appliedPlanId=v.context && v.context.plan_id;appliedFixedId=v.context && v.context.fixed_id;if(draft){updateDelete();updateScheduleDelete();if(changedStatus)state();}}
  });
  function renderAnnual() {
    var selectedPlan=plan();
    var plansBox=document.getElementById('calendar-plan');plansBox.replaceChildren();
    if(!selectedPlan)plansBox.appendChild(textOption('',newPlan?'Новый план':'План ещё не создан'));
    (draft.plans || []).forEach(function(p){plansBox.appendChild(textOption(p.id,p.name+' · '+p.start+' — '+p.end));});plansBox.value=planId || '';
    document.getElementById('plan-copy').disabled=!selectedPlan || (draft.plans || []).length>=8;
    document.getElementById('plan-new').disabled=(draft.plans || []).length>=8;
    updateDelete();
    var firstMonth=selectedPlan?Number(selectedPlan.start.slice(0,4))*12+Number(selectedPlan.start.slice(5,7))-1:0;
    var lastMonth=selectedPlan?Number(selectedPlan.end.slice(0,4))*12+Number(selectedPlan.end.slice(5,7))-1:0;
    var pages=selectedPlan?Math.ceil((lastMonth-firstMonth+1)/12):0;
    monthPage=Math.max(0,Math.min(monthPage,Math.max(0,pages-1)));
    ['months-','months-bottom-'].forEach(function(prefix){
      document.getElementById(prefix+'first').disabled=document.getElementById(prefix+'prev').disabled=!selectedPlan || monthPage===0;
      document.getElementById(prefix+'last').disabled=document.getElementById(prefix+'next').disabled=!selectedPlan || monthPage+1>=pages;
      document.getElementById(prefix+'navigation').hidden=pages<=1;
      document.getElementById(prefix+'status').textContent=pages?'Страница '+(monthPage+1)+' из '+pages+' · до 12 месяцев подряд':'';
    });
    var picker=document.getElementById('plan-brush');picker.replaceChildren(textOption('view','Просмотр — без изменений'),textOption('quiet','Тихий день / ластик'));
    if(brush!=='quiet' && !draft.schedules.some(function(s){return s.id===brush;}))brush='view';
    draft.schedules.forEach(function(s){picker.appendChild(textOption(s.id,s.name));});picker.value=brush;
    var legend=document.getElementById('plan-legend');legend.replaceChildren();
    [{id:'view',name:'Просмотр дня'},{id:'quiet',name:'Тихий день / ластик'}].concat(draft.schedules).forEach(function(item,i){
      var button=document.createElement('button');button.type='button';button.textContent=item.name;
      button.setAttribute('aria-pressed',String(brush===item.id));button.style.borderLeftColor=i>1?colorOf(item.id):'var(--muted)';
      button.addEventListener('click',function(){chooseBrush(item.id);});legend.appendChild(button);
    });
    document.getElementById('calendar-tool').textContent=brush==='view'?'Просмотр: нажатие даты не меняет план.':'Раскраска: '+scheduleName(brush)+'. Нажатия и протягивание меняют черновик.';
    document.getElementById('range-apply').disabled=brush==='view' || !selectedPlan || formPending;
    var list=planDates(),p=plan(),grid=document.getElementById('year-grid');grid.replaceChildren();
    var count=p?p.days.replace(/\./g,'').length:0;
    document.getElementById('plan-status').textContent=(p?p.name+' · '+p.start+' — '+p.end:'План ещё не создан')+': назначено '+count+' из '+list.length+' дней. Остальные тихие.';
    if(!p)return;
    for(var serial=firstMonth+monthPage*12;serial<=Math.min(lastMonth,firstMonth+monthPage*12+11);serial++) {
      var year=Math.floor(serial/12),month=serial%12+1;
      var box=document.createElement('section');box.className='calendar-month';
      var title=document.createElement('h3');title.textContent=monthNames[month-1];box.appendChild(title);
      var days=document.createElement('div');days.className='month-days';
      ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].forEach(function(w){var h=document.createElement('span');h.textContent=w;h.className='weekday';days.appendChild(h);});
      var prefix=String(year).padStart(4,'0')+'-'+String(month).padStart(2,'0')+'-';
      var first=list.findIndex(function(date){return date.startsWith(prefix);});if(first<0)continue;
      title.textContent+=' '+year;
      for(var pad=0;pad<weekday(list[first]);pad++)days.appendChild(document.createElement('span'));
      list.forEach(function(date,i) {
        if(!date.startsWith(prefix))return;
        var sid=assigned(p,i),b=document.createElement('button');b.type='button';b.textContent=Number(date.slice(-2));
        b.title=date+' · '+scheduleName(sid);b.setAttribute('aria-label',b.title);b.className='calendar-day'+(weekday(date)>=5?' weekend':'');
        if(sid!=='quiet'){b.style.background=colorOf(sid);b.style.color=ink(colorOf(sid));}
        b.dataset.index=i;b.dataset.date=date;markToday(b);
        b.addEventListener('pointerdown',function(e){
          if(e.pointerType!=='mouse' || e.button!==0 || busy || activationLock || brush==='view')return;
          e.preventDefault();painting=true;document.getElementById('preview-date').value=date;paint([i],true);
        });
        b.addEventListener('pointerenter',function(e){
          if(painting && e.pointerType==='mouse' && (e.buttons&1) && !busy && !activationLock && brush!=='view')paint([i],true);
          if(!(e.buttons&1))painting=false;
        });
        b.addEventListener('click',function(){if(!busy && !activationLock){document.getElementById('preview-date').value=date;if(brush==='view'){window.dispatchEvent(new CustomEvent('schoolbell-open-tab',{detail:'preview'}));document.getElementById('preview-day').click();}else paint([i],true);}});
        days.appendChild(b);
      });
      box.appendChild(days);grid.appendChild(box);
    }
  }
  function id(prefix) { return prefix+'_'+Date.now().toString(36)+'_'+(++counter); }
  function current() { return draft && draft.schedules.find(function (s) { return s.id===selected; }); }
  function rowEditAllowed(){return !busy && !activationLock && !window.schoolbellSessionBlocked && !!current();}
  var rowPage=0,pageSchedule=null,rowsPerPage=10;
  function showEditedRow(index){
    rowPage=Math.floor(Math.max(0,index)/rowsPerPage);
    changed();render();
    var tr=rows.children[index-rowPage*rowsPerPage];
    if(tr)tr.children[0].children[0].focus();
    else document.getElementById('row-add').focus();
  }
  function insertRow(after){
    if(!rowEditAllowed())return;
    var s=current(),index=after+1;
    s.rows.splice(index,0,{id:id('row'),time:'08:00',media:'test',enabled:true,pre:false});
    showEditedRow(index);
  }
  function moveRow(index,step){
    if(!rowEditAllowed())return;
    var list=current().rows,target=index+step;
    if(target<0 || target>=list.length)return;
    var row=list.splice(index,1)[0];list.splice(target,0,row);
    showEditedRow(target);
  }
  function state() {
    var locked=busy || activationLock || !!window.schoolbellSessionBlocked;
    document.getElementById('plan-apply').disabled=locked || !formPending;document.getElementById('plan-cancel').disabled=locked || !formPending;
    document.getElementById('workflow-draft').textContent='Черновик: '+(formPending?'название и даты ещё не применены':reconcile?'требуется повторная загрузка':!draft?'ещё не загружен':dirty?'есть несохранённые изменения':revision==='empty'?'ещё не сохранён':'сохранён');
    document.getElementById('workflow-save').disabled=locked || !draft || !dirty || reconcile || formPending;
    ['manual-media','pre-media'].forEach(function(key){
      document.getElementById(key+'-browser').disabled=locked || !draft;
      document.getElementById(key+'-device').disabled=locked || !draft || root.dataset.load.indexOf('demo-api')>=0;
    });
    ['manual-media','pre-media','pre-minutes','work-mode','fixed-schedule','active-plan'].forEach(function(id){document.getElementById(id).disabled=locked || !draft || (id==='fixed-schedule' && draft.mode!=='fixed') || (id==='active-plan' && draft.mode!=='annual');});

    document.getElementById('duty-state').textContent=busy?'Обмен с устройством…':reconcile?'Требуется сверка данных':!draft?'Данные недоступны':dirty?'Черновик изменён · не сохранён':revision==='empty'?'План ещё не сохранён':'Черновик сохранён';

    root.setAttribute('aria-busy',String(locked));
    var blocked=protectedEdit();
    save.textContent=busy?'Обмен с устройством…':formPending?'Сначала примените название и даты':reconcile?'Загрузите сохранённую копию':dirty?'💾 Сохранить черновик':'Нет изменений для сохранения';
    fields.disabled=locked || !draft;
    save.disabled=locked || !draft || !dirty || reconcile || formPending;
    reload.disabled=locked;reload.title=draft?"Отменить несохранённые правки и загрузить сохранённый черновик":"Повторить чтение сохранённых данных";
    reload.textContent=draft?"Отменить правки":"Повторить чтение";
    document.getElementById('settings-save').disabled=locked || !dirty || reconcile || formPending;
    if(blocked){save.disabled=true;document.getElementById('settings-save').disabled=true;document.getElementById('workflow-save').disabled=true;save.title=blocked;result.textContent=blocked;}
    else {save.title='';if(result.textContent.startsWith('Чтобы изменить «'))result.textContent='Можно сохранить правки.';}
    document.getElementById('settings-result').textContent=result.textContent;
    document.getElementById('preview-day').disabled=locked || formPending;
    badge.textContent=!draft?'Черновик ещё не загружен':formPending?'Есть неприменённый ввод':busy?'Обмен с устройством…':dirty?'Есть несохранённые изменения':revision==='empty'?'Пока не сохранено':'Черновик сохранён';
    badge.dataset.dirty=dirty?'true':'false';
    window.dispatchEvent(new CustomEvent('schoolbell-editor-state'));
  }
  function changed() { handoffReady=false;try{sessionStorage.removeItem(handoffKey);}catch(_){}  document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Черновик изменён. Обновите предпросмотр.'; dirty=true; result.textContent='Изменения только в браузере. Нажмите «Сохранить черновик». Активный план не меняется.'; state(); }
  function textOption(value,text) { var o=document.createElement('option'); o.value=value; o.textContent=text; return o; }
  function renderRows(s){
    if(pageSchedule!==selected){pageSchedule=selected;rowPage=0;}
    var total=s?s.rows.length:0,lastPage=Math.max(0,Math.ceil(total/rowsPerPage)-1);
    rowPage=Math.max(0,Math.min(rowPage,lastPage));
    var first=rowPage*rowsPerPage,end=Math.min(first+rowsPerPage,total);
    document.getElementById('rows-first').disabled=document.getElementById('rows-prev').disabled=rowPage===0;
    document.getElementById('rows-last').disabled=document.getElementById('rows-next').disabled=rowPage===lastPage;
    document.getElementById('rows-range').textContent=total?(first+1)+'–'+end+' из '+total:'0 из 0';
    rows.replaceChildren();
    if(s) {
      s.rows.slice(first,end).forEach(function (row,offset) {
        var index=first+offset;
        var tr=document.createElement('tr');
        function cell(control) { var td=document.createElement('td'); td.appendChild(control); tr.appendChild(td); }
        var time=document.createElement('input'); time.type='time'; time.step='60'; time.value=row.time;
        time.setAttribute('aria-label','Время звонка '+(index+1));
        time.addEventListener('input',function () { row.time=time.value; changed(); }); cell(time);
        var media=document.createElement('select'); media.setAttribute('aria-label','Мелодия звонка '+(index+1));
        mediaOptions(media,row.media);media.addEventListener('change',function(){row.media=media.value;changed();}); cell(media);
        var switches=document.createElement('div');switches.className='bell-switches';
        ['enabled','pre'].forEach(function (key) {
          var box=document.createElement('input'); box.type='checkbox'; box.className='schedule-switch';box.setAttribute('role','switch'); box.checked=row[key];
          box.setAttribute('aria-label',(key==='enabled'?'Включить звонок ':'Предзвонок ')+(index+1));
          box.addEventListener('change',function () { row[key]=box.checked; changed(); }); switches.appendChild(box);
        });
        cell(switches);
        var listening=document.createElement('div');listening.className='row-actions bell-actions';
        [['+','Добавить звонок после строки ',function(){insertRow(index);},false],
         ['▲','Переместить звонок вверх: ',function(){moveRow(index,-1);},index===0],
         ['▼','Переместить звонок вниз: ',function(){moveRow(index,1);},index===s.rows.length-1]].forEach(function(action){
          var button=document.createElement('button');button.type='button';button.textContent=action[0];button.className='row-edit';
          button.title=action[1]+(index+1);button.setAttribute('aria-label',button.title);button.disabled=action[3];
          button.addEventListener('click',action[2]);listening.appendChild(button);
        });
        [false,true].forEach(function(hardware){
          var b=document.createElement('button');b.type='button';b.textContent=hardware?'🔔':'🔊';
          b.title=hardware?'Проиграть через Школьника':'Проиграть в браузере';b.setAttribute('aria-label',b.title+' — звонок '+(index+1));
          if(hardware && root.dataset.load.indexOf('demo-api')>=0){b.disabled=true;b.title='Через Школьника недоступно: устройство не подключено';}
          b.addEventListener('click',function(){if(window.schoolbellRowPreview)window.schoolbellRowPreview(row.media,hardware);});listening.appendChild(b);
        });
        var del=document.createElement('button'); del.type='button'; del.textContent='×'; del.className='icon-delete'; del.title='Удалить звонок '+(index+1); del.setAttribute('aria-label','Удалить звонок '+(index+1));
        del.addEventListener('click',function () { if(!rowEditAllowed())return; s.rows.splice(index,1); showEditedRow(Math.min(index,s.rows.length-1)); }); listening.appendChild(del);cell(listening);rows.appendChild(tr);
      });
      document.getElementById('empty-rows').hidden=s.rows.length!==0;
      document.getElementById('row-add').disabled=false;
    }
  }
  function turnPage(step){if(rowEditAllowed()){rowPage+=step;renderRows(current());}}
  document.getElementById('rows-prev').addEventListener('click',function(){turnPage(-1);});
  document.getElementById('rows-first').addEventListener('click',function(){turnPage(-Infinity);});
  document.getElementById('rows-next').addEventListener('click',function(){turnPage(1);});
  document.getElementById('rows-last').addEventListener('click',function(){turnPage(Infinity);});
  function render() {
    // Legacy drafts are only materialized in browser memory; disk changes on explicit save.
    draft.schedules.forEach(function(s,i){if(s.color===undefined)s.color=i%16+1;});
    select.replaceChildren();
    draft.schedules.forEach(function (s) { var option=textOption(s.id,s.name);option.style.background=colorOf(s.id);option.style.color=ink(colorOf(s.id));select.appendChild(option); });
    if(!current()) selected=draft.schedules.length?draft.schedules[0].id:null;
    select.value=selected || '';
    var s=current();
    document.getElementById('selected-schedule').hidden=!s;
    document.getElementById('schedule-name-field').hidden=!s;
    document.getElementById('schedule-palette').hidden=!s;
    document.getElementById('schedule-add').disabled=draft.schedules.length>=16;
    document.getElementById('schedule-copy').disabled=!s || draft.schedules.length>=16;
    updateScheduleDelete();
    document.getElementById('pre-minutes').value=draft.pre_minutes;
    ['manual-media','pre-media'].forEach(function(id){var box=document.getElementById(id);mediaOptions(box,id==='manual-media'?(draft.manual_media || 'test'):draft.pre_media);box.disabled=false;});
    if(!draft.mode)draft.mode=(draft.plans || []).length?'annual':'fixed';
    var mode=document.getElementById('work-mode');mode.disabled=false;mode.value=draft.mode;mode.querySelector('[value="annual"]').disabled=!(draft.plans || []).length;
    var annual= document.getElementById('active-plan');
    annual.replaceChildren(textOption('','Выберите план'));
    (draft.plans || []).forEach(function(p){annual.appendChild(textOption(p.id,p.name+' · '+p.start+' — '+p.end));});
    annual.value=draft.active_plan || '';
    document.getElementById('annual-choice').hidden=draft.mode!=='annual';
    document.getElementById('fixed-choice').hidden=draft.mode!=='fixed';
    var fixed=document.getElementById('fixed-schedule');fixed.replaceChildren(textOption('quiet','Тихий день'));
    draft.schedules.forEach(function(s){fixed.appendChild(textOption(s.id,s.name));});
    if(draft.fixed_schedule===undefined)draft.fixed_schedule='quiet';
    fixed.value=draft.fixed_schedule;fixed.disabled=draft.mode!=='fixed';document.getElementById('pre-minutes').disabled=false;
    document.getElementById('work-mode-hint').textContent=draft.mode==='annual'?'Звонки подаются только по выбранному плану. Вне его дат звонков нет.':'Одно расписание на каждый день. По умолчанию — тихий день.';
    if(s)name.value=s.name;
    renderRows(s);
    renderColors();
    renderAnnual();
    state();
  }
  var errors={
    conflict:'Расписания изменены в другой вкладке. Ваши правки сохранены в браузере. Для загрузки сохранённой копии нажмите «Отменить правки».',
    invalid:'Не удалось сохранить: проверьте время, название, флажки и лимиты.',
    space:'Недостаточно свободного места с защитным запасом. Черновик в браузере сохранён.',
    recovery_required:'Сохранённые данные повреждены или неполны. Они не заменены. Нужна проверка по SSH.',
    busy:'Хранилище временно занято. Повторите чтение.',
    storage_unavailable:'Хранилище недоступно. Автоматический повтор не выполняется.',
    storage_uncertain:'Результат записи не подтверждён. Не повторяем сохранение: для загрузки сохранённой копии нажмите «Отменить правки».',
    revision:'Неизвестная ревизия. Загрузите данные устройства.',size:'Превышен размер черновика: 12 КиБ.'
  };
  async function request(url,options) {
    var controller=new AbortController(),timer=setTimeout(function(){controller.abort();},15000);
    try {
      var response=await fetch(url,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error',signal:controller.signal},options));
      if(!response.ok) throw new Error('http');
      return await response.json();
    } finally {clearTimeout(timer);}

  }
  // Only idempotent draft GETs retry explicit contention; POSTs never replay.
  async function readDraft() {
    var epoch=sessionEpoch;
    for(var attempt=0;attempt<3;attempt++) {
      if(window.schoolbellSessionBlocked || epoch!==sessionEpoch)throw Error('session');
      var value=await request(root.dataset.load);
      if(window.schoolbellSessionBlocked || epoch!==sessionEpoch)throw Error('session');
      if(value.ok || value.code!=='busy' || attempt===2)return value;
      result.textContent='Хранилище временно занято. Повторяем чтение…';state();
      await new Promise(function(resolve){setTimeout(resolve,500*(attempt+1));});
    }
  }
  function readGuard(){return JSON.stringify([draft,formPending,newPlan,copyPlan,
    document.getElementById('plan-name').value,document.getElementById('plan-start').value,
    document.getElementById('plan-end').value]);}
  function prepareNavigation(){
    try{
      if((dirty || formPending) && draft){
        var text=JSON.stringify({user:document.getElementById('session-panel').dataset.user,until:Date.now()+8*3600000,revision:revision,selected:selected,monthPage:monthPage,planId:planId,form:formPending?{name:document.getElementById('plan-name').value,start:document.getElementById('plan-start').value,end:document.getElementById('plan-end').value,newPlan:newPlan,copyPlan:copyPlan}:null,data:draft});
        if(text.length>32768)return false;
        sessionStorage.setItem(handoffKey,text);
        if(sessionStorage.getItem(handoffKey)!==text)return false;
      }else sessionStorage.removeItem(handoffKey);
      handoffReady=true;return true;
    }catch(_){return false;}
  }
  function restoreNavigation(){
    try{
      var text=sessionStorage.getItem(handoffKey);if(!text)return false;
      sessionStorage.removeItem(handoffKey);
      if(text.length>32768)return false;var kept=JSON.parse(text);
      if(kept.user!==document.getElementById('session-panel').dataset.user || typeof kept.until!=='number' || !Number.isFinite(kept.until) || kept.until<Date.now() || kept.until>Date.now()+8*3600000 || typeof kept.revision!=='string' || !kept.data || !Array.isArray(kept.data.schedules))return false;
      var local=normalize(kept.data);if(local.schedules.length>16 || (local.plans || []).length>8)return false;
      reconcile=kept.revision!==revision;draft=local;selected=local.schedules.some(function(s){return s.id===kept.selected;})?kept.selected:null;planId=kept.planId;fillPlan();if(Number.isInteger(kept.monthPage)&&kept.monthPage>=0)monthPage=kept.monthPage;if(kept.form){formPending=true;newPlan=!!kept.form.newPlan;copyPlan=kept.form.copyPlan;['name','start','end'].forEach(function(k){document.getElementById('plan-'+k).value=kept.form[k];});}dirty=true;return true;
    }catch(_){return false;}
  }
  async function load() {
    if(busy || activationLock || window.schoolbellSessionBlocked)return;
    if((dirty || formPending) && !window.confirm('Заменить несохранённые изменения данными с устройства?')) return;
    var guard=readGuard();
    busy=true; state();
    try {
      var value=await readDraft();
      if(guard!==readGuard()){reconcile=true;result.textContent="Во время чтения появились правки. Они остались в браузере.";return;}
      if(!value.ok) { result.textContent=(errors[value.code] || 'Ошибка чтения.')+(draft?' Правки в браузере не изменены.':' Черновик ещё не загружен.')+(draft?' Чтобы загрузить сохранённую копию, нажмите «Отменить правки».':' Нажмите «Повторить чтение».'); reconcile=!!draft; return; }
      document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Предпросмотр использует текущий черновик.'; draft=normalize(value.data);savedDraft=JSON.parse(JSON.stringify(draft));if(!draft.plans.some(function(p){return p.id===planId;}))planId=draft.plans[0]?.id || null;fillPlan(); revision=value.revision; dirty=false; reconcile=false;  brush='view'; render();
      result.textContent=revision==='empty'?'Сохранённых расписаний ещё нет. Создайте первое.':'Черновик прочитан с устройства. Состояние автозвонков указано в верхней плашке.';
      if(restoreNavigation()){render();result.textContent=reconcile?'Правки восстановлены. Сохранённый план изменился: загрузите сохранённую копию кнопкой «Отменить правки».':'Несохранённые правки восстановлены после входа. Автозвонки не включались.';}
    } catch (_) { result.textContent='Не удалось загрузить данные. Проверьте вход и повторите чтение.'+(draft?' Правки в браузере не изменены.':' Черновик ещё не загружен.'); }
    finally { busy=false; state(); }
  }
  function canonical(value) {
    if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
    if(value && typeof value==='object')return '{'+Object.keys(value).sort().map(function(k){return JSON.stringify(k)+':'+canonical(value[k]);}).join(',')+'}';
    return JSON.stringify(value);
  }
  function normalize(value) {
    var data=JSON.parse(JSON.stringify(value));
    data.plans=R.migrate(data.plans || []);
    data.schedules.forEach(function(s,i){if(s.color===undefined)s.color=i%16+1;});
    if(data.mode===undefined)data.mode=(data.plans || []).length?'annual':'fixed';
    if(data.fixed_schedule===undefined)data.fixed_schedule='quiet';
    return data;
  }
  select.addEventListener('change',function () { selected=select.value; render(); });
  name.addEventListener('input',function () {
    if(!current()) return; current().name=name.value;
    select.options[select.selectedIndex].textContent=name.value; changed(); renderAnnual();
  });
  document.getElementById('settings-save').addEventListener('click',function(){save.click();});
  document.getElementById('active-plan').addEventListener('change',function(e){
    if(e.target.value)draft.active_plan=e.target.value;else delete draft.active_plan;
    changed();render();
  });
  ['manual-media','pre-media'].forEach(function(key){
    ['browser','device'].forEach(function(route){
      document.getElementById(key+'-'+route).addEventListener('click',function(){
        window.schoolbellRowPreview(document.getElementById(key).value,route==='device',document.getElementById('settings-preview-status'));
      });
    });
  });
  [['manual-media','manual_media'],['pre-media','pre_media'],['work-mode','mode'],['fixed-schedule','fixed_schedule']].forEach(function(pair){document.getElementById(pair[0]).addEventListener('change',function(e){draft[pair[1]]=e.target.value;changed();render();});});
  document.getElementById('pre-minutes').addEventListener('input',function (e) { draft.pre_minutes=Number(e.target.value); changed(); });
  document.getElementById('schedule-add').addEventListener('click',function () {
    if(draft.schedules.length>=16) return;
    var s={id:id('schedule'),name:'Новое расписание',color:nextColor(),rows:[]}; draft.schedules.push(s); selected=s.id; changed(); render(); name.focus(); name.select();
  });
  document.getElementById('schedule-copy').addEventListener('click',function () {
    if(!current() || draft.schedules.length>=16) return;
    var s=JSON.parse(JSON.stringify(current())); s.id=id('schedule'); s.color=nextColor(); s.name=Array.from(s.name).slice(0,20).join('')+' — копия';
    draft.schedules.push(s); selected=s.id; changed(); render();
  });
  document.getElementById('schedule-delete').addEventListener('click',function () {
    if(!current() || busy || activationLock)return;
    if(appliedFixedId===selected){result.textContent='Это применённое ежедневное расписание. Сначала примените другой выбор.';return;}
    if(draft.fixed_schedule===selected){result.textContent='Это ежедневное расписание. В «Настройках» явно выберите другое или «Тихий день», затем повторите удаление. Активный план не меняется.';return;}
    var used=(draft.plans || []).some(function(p){var i=p.schedule_ids.indexOf(selected);return i>=0 && p.days.includes(String.fromCharCode(65+i));});
    if(used){result.textContent='Расписание назначено датам. Сначала снимите назначения во всех планах.';return;}
    if(!window.confirm('Удалить расписание «'+current().name+'» из черновика? Активный план не изменится.'))return;
    (draft.plans || []).forEach(prune);
    draft.schedules=draft.schedules.filter(function (s) { return s.id!==selected; }); selected=null; changed(); render();
  });
  document.getElementById('row-add').addEventListener('click',function () {
    if(current())insertRow(current().rows.length-1);
  });
  document.getElementById('rows-clear').addEventListener('click',function () {
    if(!rowEditAllowed() || !window.confirm('Удалить все звонки расписания «'+current().name+'»? Всего строк: '+current().rows.length+'.')) return;
    current().rows=[]; changed(); render();
  });
  save.addEventListener('click',async function () {
    if(busy || activationLock || !draft || !dirty || reconcile || formPending || protectedEdit())return;
    busy=true; state(); result.textContent='Сохраняем без активации…';
    try {
      try{R.validateDraft(draft,root.dataset.load.indexOf('demo-api')>=0);}catch(e){result.textContent=e.message;return;}
      var body=new URLSearchParams({token:root.dataset.token,revision:revision,draft:JSON.stringify(draft)});
      var value=await request(root.dataset.save,{method:'POST',body:body});
      if(!value.ok) {
        reconcile=['storage_uncertain','recovery_required','conflict','plan_in_use','schedule_in_use'].includes(value.code);
        result.textContent=(value.code==='source_running'?'Чтобы изменить «'+(value.detail && value.detail.name || 'рабочий источник')+'», остановите автозвонки.':value.code==='plan_in_use'?'Удаление отклонено: план применён на устройстве. Загрузите сохранённую копию или сверьте правки.':value.code==='schedule_in_use'?'Удаление отклонено: ежедневное расписание применено на устройстве. Сверьте правки.':errors[value.code] || 'Ошибка сохранения.');
        return;
      }
      document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Предпросмотр использует текущий черновик.'; draft=normalize(value.data);savedDraft=JSON.parse(JSON.stringify(draft));if(!draft.plans.some(function(p){return p.id===planId;}))planId=draft.plans[0]?.id || null;fillPlan(); revision=value.revision; dirty=false; reconcile=false; render();
      result.textContent='Сохранено на устройстве. Активный план не меняется до отдельного применения.'+(value.journal_warning?' Внимание: событие не удалось записать в журнал.':'');
    } catch (_) { reconcile=true; result.textContent='Ответ потерян: запись могла завершиться. Правки остались в браузере. Чтобы загрузить сохранённую копию, нажмите «Отменить правки».'; }
    finally { busy=false; state(); }
  });
  ['name','start','end'].forEach(function(k){document.getElementById('plan-'+k).addEventListener('input',function(){formPending=true;handoffReady=false;state();formStatus('Примените название и даты к черновику или отмените ввод.');});});
  document.getElementById('calendar-plan').addEventListener('change',function(e){if(!leaveForm()){renderAnnual();return;}planId=e.target.value;fillPlan();brush='view';render();formStatus('');});
  document.getElementById('plan-new').addEventListener('click',function(){
    if(!leaveForm())return;planId=null;fillPlan();newPlan=true;formPending=true;
    var suggested=routerDate && performance.now()-routerDate.at<45000?R.suggest(routerDate.date,true):null;
    document.getElementById('plan-name').value=suggested?suggested.name:'Новый план';
    document.getElementById('plan-start').value=suggested?suggested.start:'';document.getElementById('plan-end').value=suggested?suggested.end:'';
    formStatus(suggested?'Проверьте предложенный учебный год.':'Нет свежей подтверждённой даты устройства. Укажите диапазон вручную.');render();
  });
  document.getElementById('plan-copy').addEventListener('click',function(){if(!plan() || !leaveForm())return;var p=JSON.parse(JSON.stringify(plan()));planId=null;fillPlan();copyPlan=p;newPlan=true;formPending=true;document.getElementById('plan-name').value=p.name+' — копия';document.getElementById('plan-start').value=p.start;document.getElementById('plan-end').value=p.end;formStatus('Задайте непересекающиеся даты. Назначения будут перенесены по порядку дней, не по дням недели.');render();});
  document.getElementById('plan-cancel').addEventListener('click',function(){if(leaveForm()){if(!plan())planId=draft.plans[0]?.id || null;fillPlan();render();formStatus('Ввод отменён.');}});
  document.getElementById('plan-apply').addEventListener('click',function(){
    if(busy || activationLock)return;
    try{
      var p=plan(),first=document.getElementById('plan-start').value,last=document.getElementById('plan-end').value,title=document.getElementById('plan-name').value.trim();
      var count=R.ordinal(last)-R.ordinal(first)+1;if(count<1)throw Error('Окончание раньше начала');
      if(count>12288)throw Error('Данные этого диапазона не поместятся в черновик 12 КиБ. Прежний план сохранён.');
      var resized=p?R.resize(p,first,last,title):{removed:0,plan:{id:id('plan'),name:title,start:first,end:last,schedule_ids:copyPlan?[...copyPlan.schedule_ids]:[],days:copyPlan?(copyPlan.days+'.'.repeat(count)).slice(0,count):'.'.repeat(count)}};
      var candidate=JSON.parse(JSON.stringify(draft));candidate.plans=candidate.plans.filter(function(q){return q.id!==resized.plan.id;}).concat([resized.plan]);R.validate(candidate.plans);
      if(new TextEncoder().encode(JSON.stringify(candidate)).length>12288)throw Error('Черновик превышает 12 КиБ. Прежний план сохранён.');
      if(resized.removed && !window.confirm('За границами будут удалены назначения '+resized.removed+' дат. Продолжить?'))return;
      if(copyPlan && !window.confirm('Скопировать по порядку дней? Дни недели могут отличаться.'))return;
      draft=candidate;planId=resized.plan.id;fillPlan();brush='view';changed();render();formStatus('План изменён в черновике. Сохранение и активация — отдельные действия.');
    }catch(e){formStatus(e.message);}
  });
  ['months-','months-bottom-'].forEach(function(prefix){['first','prev','next','last'].forEach(function(direction){document.getElementById(prefix+direction).addEventListener('click',function(){
    var p=plan();if(!p)return;painting=false;if(direction==='first')monthPage=0;else if(direction==='last'){var first=Number(p.start.slice(0,4))*12+Number(p.start.slice(5,7)),last=Number(p.end.slice(0,4))*12+Number(p.end.slice(5,7));monthPage=Math.ceil((last-first+1)/12)-1;}else monthPage+=direction==='next'?1:-1;renderAnnual();
    if(prefix==='months-bottom-')document.getElementById('months-navigation').scrollIntoView({block:'start'});
  });});});
  document.getElementById('plan-brush').addEventListener('change',function(e){chooseBrush(e.target.value);});
  document.getElementById('range-apply').addEventListener('click',function(){
    if(brush==='view' || busy || activationLock || formPending)return;
    var list=planDates(),first=list.indexOf(document.getElementById('range-first').value),last=list.indexOf(document.getElementById('range-last').value);
    if(first<0 || last<first){document.getElementById('plan-status').textContent='Укажите корректный диапазон внутри выбранного плана.';return;}
    var filter=document.getElementById('range-filter').value,indices=[];
    for(var i=first;i<=last;i++){var w=weekday(list[i]);if(filter==='all' || (filter==='weekdays' && w<5) || (filter==='weekends' && w>=5))indices.push(i);}
    if(indices.length && window.confirm('Назначить «'+scheduleName(brush)+'» для '+indices.length+' дат?'))paint(indices);
  });
  document.getElementById('year-clear').addEventListener('click',function(){
    if(deletionReason())return;
    if(!plan() || busy || activationLock || !leaveForm())return;
    var lastAnnual=draft.mode==='annual' && draft.plans.length===1;
    var consequence=lastAnnual?' Это последний план. В черновике будет выбран режим «По расписанию» и «Тихий день».':'';
    if(window.confirm('Удалить план «'+plan().name+'» и его назначения?' +consequence+' Активный план не изменится; черновик потребуется сохранить и применить отдельно.')){
      if(draft.active_plan===planId)delete draft.active_plan;draft.plans=draft.plans.filter(function(p){return p.id!==planId;});if(lastAnnual){draft.mode='fixed';draft.fixed_schedule='quiet';}planId=draft.plans[0]?.id || null;fillPlan();changed();render();
    }
  });
  document.getElementById('preview-day').addEventListener('click',async function(){
    if(busy || activationLock || !draft)return;
    busy=true;state();var status=document.getElementById('preview-status'),output=document.getElementById('preview-events');output.replaceChildren();
    if(draft.mode==='annual' && !draft.active_plan){status.textContent='Черновик · выберите календарный план в Настройках.';busy=false;state();return;}
    status.textContent='Вычисляем текущий черновик без сохранения и звука…';
    try {
      var value=await request(root.dataset.preview,{method:'POST',body:new URLSearchParams({token:root.dataset.token,draft:JSON.stringify(draft),date:document.getElementById('preview-date').value})});
      if(!value.ok){status.textContent='Предпросмотр отклонён: '+(value.detail?(value.detail.path || value.detail.code):value.code);return;}
      var chosenPlan=draft.mode==='annual' && draft.plans.find(function(p){return p.id===draft.active_plan;});
      var source=chosenPlan?' · план «'+chosenPlan.name+'»':' · ежедневное расписание';
      if(chosenPlan && (value.date<chosenPlan.start || value.date>chosenPlan.end))source+=' · вне дат плана';
      status.textContent='Черновик'+source+(dirty || revision==='empty'?' · НЕ СОХРАНЁН':' · сохранён')+' · '+value.date+' · '+scheduleName(value.selected_schedule)+' · '+value.events.length+' событий. Местные часы; не UTC и не проверка переходов часов.';
      value.events.forEach(function(e){
        var li=document.createElement('li');li.style.borderLeft='10px solid '+colorOf(e.schedule_id);li.style.paddingLeft='10px';
        li.textContent=e.time+' — '+(e.kind==='pre'?'Предзвонок':'Основной звонок')+' · '+scheduleName(e.schedule_id)+' · ';
        var title=document.createElement('span');title.dataset.media=e.media;title.textContent=mediaLabel(e.media);li.appendChild(title);
        if(e.origin_date!==e.date){var origin=document.createElement('span');origin.textContent=' (основной звонок '+e.origin_date+')';li.appendChild(origin);}
        output.appendChild(li);
      });
      if(!value.events.length){var li=document.createElement('li');li.textContent='В этот день звонков нет.';output.appendChild(li);}
    } catch(_){status.textContent='Предпросмотр недоступен. Проверьте соединение и вход LuCI.';}
    finally{busy=false;state();}
  });
  window.addEventListener('pointerup',function(){painting=false;});
  window.addEventListener('pointercancel',function(){painting=false;});
  window.addEventListener('blur',function(){painting=false;});
  window.schoolbellEditor={systemLock:function(){if(busy||activationLock)return false;activationLock=true;state();return true;},systemResetComplete:function(){dirty=false;formPending=false;reconcile=false;handoffReady=false;try{sessionStorage.removeItem(handoffKey);}catch(_){}activationLock=true;state();},exportSnapshot:function(){return {draft:draft?JSON.parse(JSON.stringify(draft)):null,dirty:dirty||formPending,busy:busy||activationLock,reconcile:reconcile,revision:revision};},prepareNavigation:prepareNavigation,snapshot:function(){return {needsPlan:!!draft && draft.mode==='annual' && !draft.active_plan,loaded:!!draft,dirty:dirty || formPending,busy:busy || activationLock,reconcile:reconcile,revision:revision};},lock:function(options){if(busy || activationLock || !draft || dirty || formPending || reconcile || (revision==='empty' && !(options && options.allowEmpty)))return false;activationLock=true;state();return true;},reloadImported:async function(){if(dirty||formPending)return false;activationLock=false;await load();return true;},unlock:function(){activationLock=false;state();}};
  document.getElementById('workflow-save').addEventListener('click',function(){save.click();});
  reload.addEventListener('click',load);
  window.addEventListener('beforeunload',function (e) { if((dirty || formPending) && !handoffReady) { e.preventDefault(); e.returnValue=''; } });
  window.addEventListener('schoolbell-session-lost',function(){
    sessionEpoch++;
    reconcile=true;
    result.textContent='Сеанс недоступен. Правки остаются в этой вкладке; после входа можно загрузить сохранённую копию кнопкой «Отменить правки».';state();
  });
  window.schoolbellInitialDraft=load();
}());
