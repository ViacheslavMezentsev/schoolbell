(function(){
 'use strict';
 const $=id=>document.getElementById('portable-'+id),config=window.SchoolbellPortableConfig;
 const api=window.SchoolbellPortablePages.create(window.SchoolbellPlanCodec,window.SchoolbellPlanExport,window.SchoolbellPlanPreview,window.crypto,config);
 const status=$('status'),result=$('result'),zone=$('zone');let epoch=0,loaded=null,busy=false,last='',planKey='',renames={plans:[],schedules:[]};
 const errors={size:'Превышен размер или число элементов.',format:'Неверный формат файла.',checksum:'Контрольная сумма не совпала.',truncated:'Файл обрезан.',trailing:'В конце файла есть лишние данные.',unsupported_media:'Pages поддерживает только штатные мелодии. Этот файл требует пользовательские MP3.',timezone:'Выберите совпадающий часовой пояс из закреплённого списка. Часы не изменяются.',selection:'Выберите хотя бы один план.',dependency:'Не совпадают или отсутствуют зависимости, включая штатные мелодии.',pending:'Завершите ввод названия и дат, дождитесь операции или сверки черновика.',unavailable:'Дождитесь чтения черновика.',dirty:'Сначала сохраните черновик в демо.',automatic_enabled:'Выключите модель автозвонков перед проверкой.',overlap:'Диапазоны дат пересекаются с существующими планами.',name_conflict:'Название уже занято. Измените импортируемое название в полях выше и повторите проверку.',pre_conflict:'Предзвонок конфликтует с существующими расписаниями.',conflict:'Изменилось исходное состояние. Повторите проверку.',slots:'Недостаточно свободных позиций.',io:'Не удалось прочитать файл.'};
 function fail(e){status.textContent=errors[e.message]||'Не удалось выполнить операцию. Проверьте файл и поддержку Web Crypto (HTTPS или localhost).';}
 function snap(){return window.schoolbellEditor?.portableSnapshot();}
 function signature(){return JSON.stringify([snap(),zone.value,window.schoolbellDemo?.portableState()]);}
 function invalidate(){epoch++;result.replaceChildren();}
 function refresh(){const s=snap(),sig=signature();if(sig!==last){last=sig;invalidate();if(loaded)status.textContent='Исходные данные изменились. Повторите проверку; импорт ничего не записывал.';}
  const plans=s?.draft?.plans||[],key=JSON.stringify(plans.map(p=>[p.id,p.name,p.start,p.end]));
  if(key!==planKey){const selected=new Set(Array.from($('plans').querySelectorAll('input:checked'),x=>x.value));$('plans').replaceChildren();for(const p of plans){const label=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.value=p.id;input.checked=selected.has(p.id);label.append(input,document.createTextNode(' '+p.name+' · '+p.start+' — '+p.end));label.style.display='block';$('plans').append(label);}planKey=key;}
  $('export').disabled=busy||!s?.draft||s.busy||s.formPending||s.reconcile||!zone.value;
  $('file').disabled=busy;
  $('preview').disabled=busy||!loaded||!s?.draft||s.busy||s.formPending||s.reconcile||!zone.value;
 }
 for(const name of Object.keys(config.zones).sort()){const o=document.createElement('option');o.value=name;o.textContent=name;zone.append(o);}
 $('zone-hint').textContent='Зона браузера (подсказка): '+(Intl.DateTimeFormat().resolvedOptions().timeZone||'неизвестна')+'. Выбор здесь не меняет часы или настройки демо. Правила LuCI 19.07; совместимость проверяется по имени и POSIX-правилам.';
 zone.addEventListener('change',refresh);
 $('plans').addEventListener('change',()=>{invalidate();});
 window.addEventListener('schoolbell-editor-state',refresh);
 window.addEventListener('storage',refresh);
 $('export').addEventListener('click',async()=>{if(busy)return;refresh();const s=snap(),name=zone.value,selected=Array.from($('plans').querySelectorAll('input:checked'),x=>x.value);invalidate();const token=epoch,sig=signature();busy=true;refresh();status.textContent='Собираем файл…';
  try{const blob=await api.exportFile(s,selected,name);if(token!==epoch||signature()!==sig)throw Error('conflict');const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='schoolbell-plans.sbp';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);status.textContent='Файл .sbp подготовлен'+(s.dirty?' из несохранённого черновика':'')+'. Сохранение и включение плана не выполнялись.';}catch(e){fail(e);}finally{busy=false;refresh();}
 });
 $('file').addEventListener('change',async()=>{if(busy)return;refresh();invalidate();loaded=null;$('names').replaceChildren();renames={plans:[],schedules:[]};const file=$('file').files[0];if(!file){refresh();return;}const token=epoch;busy=true;refresh();status.textContent='Проверяем формат и контрольные суммы…';
  try{const value=await api.readFile(file);if(token!==epoch)return;loaded=value;
   for(const kind of ['plans','schedules'])for(const entry of value.summary[kind]){const label=document.createElement('label'),input=document.createElement('input');label.textContent=(kind==='plans'?'Название импортируемого плана: ':'Название импортируемого расписания: ');input.value=entry.name;input.maxLength=96;input.addEventListener('input',()=>{invalidate();status.textContent='Название изменено. Повторите проверку.';});label.append(input);label.style.display='block';$('names').append(label);renames[kind].push([entry.id,input]);}
   status.textContent='Файл проверен: '+value.summary.plans.length+' план(а), '+value.summary.schedules.length+' расписаний; пояс '+value.timezone.name+'. Выберите пояс назначения и проверьте добавление.';
  }catch(e){if(token===epoch)fail(e);}finally{busy=false;refresh();}
 });
 $('preview').addEventListener('click',()=>{if(busy||!loaded)return;refresh();invalidate();try{const names={plans:Object.fromEntries(renames.plans.map(([id,input])=>[id,input.value])),schedules:Object.fromEntries(renames.schedules.map(([id,input])=>[id,input.value]))};const p=api.preview(loaded,snap(),zone.value,names,!!window.schoolbellDemo.portableState().automatic_enabled);
   status.textContent=p.ok?'Проверка пройдена. Это предварительный результат: ничего не добавлено и не включено.':'Добавление пока невозможно. Текущие данные не изменены.';
   const lines=p.ok?[...p.mapping.plans.map(x=>'План: '+x.name),...p.mapping.schedules.map(x=>'Расписание: '+x.name),'Размер объединённого черновика: '+p.candidate_bytes+' байт','Предзвонок: '+p.pre_change.before.minutes+' → '+p.pre_change.after.minutes+' мин; '+p.pre_change.before.media+' → '+p.pre_change.after.media]:p.blockers.map(x=>(errors[x.code]||x.code)+' ['+x.path+']');
   for(const line of lines){const li=document.createElement('li');li.textContent=line;result.append(li);}
  }catch(e){fail(e);}
 });
 setInterval(refresh,1000);refresh();
})();
