(function(global){
  'use strict';
  function dateKey(t){return new Date(t).toISOString().slice(0,10);}
  function parseDate(s){
    if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(s))throw Error('date');
    var t=Date.parse(s+'T00:00:00Z');if(!Number.isFinite(t)||dateKey(t)!==s)throw Error('date');return t;
  }
  function model(value){
    if(!value||!value.ok||!Array.isArray(value.days)||value.days.length>400)throw Error('metrics');
    var today=parseDate(value.today),counts=Object.create(null);
    value.days.forEach(function(d){parseDate(d.date);if(!Number.isInteger(d.count)||d.count<0||d.count>2147483647||counts[d.date]!==undefined)throw Error('count');counts[d.date]=d.count;});
    var monday=today-((new Date(today).getUTCDay()+6)%7)*86400000,start=monday-32*7*86400000,days=[];
    for(var i=0;i<231;i++){var t=start+i*86400000,k=dateKey(t);days.push({date:k,count:counts[k]===undefined?null:counts[k],future:t>today});}
    return {days:days,start:dateKey(start),today:value.today,pending:!!value.persistence_pending,demo:!!value.demo};
  }
  function level(n){return n===null?'unknown':n===0?'0':n<=10?'1':n<=20?'2':n<=30?'3':'4';}
  if(typeof module==='object'&&module.exports){module.exports={model:model,level:level};return;}
  var root=document.querySelector('.bell-activity');if(!root)return;
  var panel=document.getElementById('metrics-panel'),grid=document.getElementById('bell-activity-grid'),detail=document.getElementById('bell-activity-detail'),source=document.getElementById('bell-activity-source');
  var weekdays=['Пн','Вт','Ср','Чт','Пт','Сб','Вс'],months=['Янв','Фев','Мар','Апр','Май','Июн','Июл','Авг','Сен','Окт','Ноя','Дек'];
  var busy=false,last=null,epoch=0,hasData=false,selected=null,abort;
  function text(d,index){return weekdays[index%7]+' '+d.date.split('-').reverse().join('.')+' · '+(d.count===null?'нет учтённых данных':'учтено автозвонков: '+d.count);}
  function draw(data){
    grid.replaceChildren();source.textContent=data.demo?'Демо · оборудование не подключено':data.pending?'Сохранение статистики не подтверждено':'Учтённые автозвонки';
    detail.textContent=data.start.split('-').reverse().join('.')+' — '+data.today.split('-').reverse().join('.')+' · выберите день';
    weekdays.forEach(function(name,i){var e=document.createElement('span');e.className='bell-activity-axis';e.textContent=i%2===0?name:'';e.style.gridColumn='1';e.style.gridRow=String(i+2);grid.appendChild(e);});
    var month=-1;
    data.days.forEach(function(d,i){
      var week=Math.floor(i/7),m=Number(d.date.slice(5,7))-1;
      if(i%7===0&&m!==month){month=m;var label=document.createElement('span');label.className='bell-activity-axis';label.textContent=months[m];label.style.gridColumn=String(week+2);label.style.gridRow='1';grid.appendChild(label);}
      var button=document.createElement('button');button.type='button';button.className='bell-activity-day';button.style.gridColumn=String(week+2);button.style.gridRow=String(i%7+2);
      button.dataset.level=level(d.count);button.dataset.future=String(d.future);button.disabled=d.future;
      var labelText=text(d,i);button.title=labelText;button.setAttribute('aria-label',labelText);button.setAttribute('aria-pressed',String(selected===d.date));
      if(selected===d.date)detail.textContent=labelText;
      button.addEventListener('click',function(){selected=d.date;grid.querySelectorAll('[aria-pressed="true"]').forEach(function(b){b.setAttribute('aria-pressed','false');});button.setAttribute('aria-pressed','true');detail.textContent=labelText;});grid.appendChild(button);
    });
  }
  function clear(message){grid.replaceChildren();detail.textContent=message;source.textContent='Нет данных';}
  async function load(){
    if(busy||!panel.open||document.hidden||global.schoolbellSessionBlocked)return;
    if(!global.schoolbellEditor||!global.schoolbellEditor.snapshot().loaded)return;
    if(last!==null && performance.now()-last<60000)return;
    var started=epoch;busy=true;last=performance.now();abort=new AbortController();var timer=setTimeout(function(){abort.abort();},10000);
    try{var r=await fetch(root.dataset.url,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});if(!r.ok)throw Error('http');var data=model(await r.json());if(started===epoch && !global.schoolbellSessionBlocked){draw(data);hasData=true;}}
    catch(_){if(started===epoch){if(hasData)source.textContent='Последние данные · обновить не удалось';else clear('Не удалось прочитать статистику. Повторим чтение автоматически.');}}
    finally{clearTimeout(timer);busy=false;abort=null;}
  }
  panel.addEventListener('toggle',function(){if(panel.open)load();});
  document.addEventListener('visibilitychange',function(){if(!document.hidden)load();});
  global.addEventListener('schoolbell-session-lost',function(){epoch++;last=null;hasData=false;selected=null;if(abort)abort.abort();clear('Войдите снова, чтобы прочитать статистику.');});
  setInterval(function(){load();},5000);setTimeout(function(){load();},2000);
})(typeof window==='object'?window:this);
