/* Passive, tab-local API counters; no requests, storage or payload inspection. */
(function(global){
  'use strict';
  // Fixed names only: never keep URL queries, tokens, bodies or arbitrary paths.
  var routes={automatic:'Состояние автоматики',schedules:'Расписания',journal:'Журнал',controls:'Состояние звука',clock:'Часы',trust:'Проверка времени',timezone:'Часовой пояс',media:'Медиатека',preview:'Предпросмотр',session:'Сеанс',backup:'Резервная копия',manual:'Ручной звонок',test:'Тестовый звонок',other:'Другой метод API'};
  function counters(){return {reads:0,commands:0,errors:0,finished:0,total:0,max:0};}
  function create(clock){
    var slots=[],pending=0,waiting={};
    function bucket(){var key=Math.floor(clock()/5000),b=slots.find(function(x){return x.key===key;});
      slots=slots.filter(function(x){return x.key>key-12;});
      if(!b){b=Object.assign({key:key,methods:{}},counters());slots.push(b);}return b;}
    return {
      begin:function(method,route){
        route=Object.prototype.hasOwnProperty.call(routes,route)?route:'other';
        var verb=['GET','HEAD','POST'].indexOf(method)!==-1?method:'OTHER',id=verb+' '+route,b=bucket();
        var group=b.methods[id]||(b.methods[id]=Object.assign({id:id,verb:verb,route:route},counters()));
        var kind=verb==='GET'||verb==='HEAD'?'reads':'commands';b[kind]++;group[kind]++;pending++;waiting[id]=(waiting[id]||0)+1;
        return {bucket:b,group:group,start:clock(),done:false};
      },
      end:function(ticket,failed){if(ticket.done)return;ticket.done=true;pending--;waiting[ticket.group.id]--;var ms=Math.max(0,clock()-ticket.start);
        [ticket.bucket,ticket.group].forEach(function(b){b.finished++;b.total+=ms;b.max=Math.max(b.max,ms);if(failed)b.errors++;});
      },
      snapshot:function(){var current=bucket(),items=[],groups={};
        for(var key=current.key-11;key<=current.key;key++){
          var b=slots.find(function(x){return x.key===key;});items.push(Object.assign({key:key},counters(),b));
          if(b)Object.keys(b.methods).forEach(function(id){var g=b.methods[id],sum=groups[id]||(groups[id]=Object.assign({id:id,verb:g.verb,route:g.route},counters()));
            Object.keys(counters()).forEach(function(k){sum[k]=k==='max'?Math.max(sum[k],g[k]):sum[k]+g[k];});});
        }
        Object.keys(waiting).forEach(function(id){if(waiting[id]&&!groups[id]){var parts=id.split(' ');groups[id]=Object.assign({id:id,verb:parts[0],route:parts[1]},counters());}});
        var methods=Object.keys(groups).sort().map(function(id){return Object.assign({},groups[id],{pending:waiting[id]||0});});
        return {items:items,pending:pending,methods:methods};
      }
    };
  }
  function observe(fetcher,model,accept){return function(input,options){
    var route=accept(input);if(!route)return fetcher(input,options);
    var ticket=model.begin(String(options&&options.method || input&&input.method || 'GET').toUpperCase(),route);
    try{return Promise.resolve(fetcher(input,options)).then(function(response){model.end(ticket,!response.ok);return response;},function(error){model.end(ticket,true);throw error;});}
    catch(error){model.end(ticket,true);throw error;}
  };}
  if(typeof module==='object'&&module.exports){module.exports={create:create,observe:observe};return;}
  var chart=document.getElementById('traffic-chart');if(!chart)return;
  var root=document.getElementById('schedule-editor'),panel=document.getElementById('session-panel');
  var endpoints=new Map(),data=Object.assign({},root.dataset,{session:panel.dataset.session,backup:document.getElementById('backup-panel')?.dataset.url});
  // Only explicitly supplied module endpoints, never unrelated fetches or audio streams.
  ['media','trust','automatic','controls','manual','timezone','journal','clock','preview','load','save','session','backup'].forEach(function(key){if(!data[key])return;try{var u=new URL(data[key],location.href);if(u.origin===location.origin&&key!=='sample')endpoints.set(u.pathname,key==='load'||key==='save'?'schedules':key);}catch(_){}});
  var form=document.getElementById('router-form');if(form)endpoints.set(new URL(form.action,location.href).pathname,'test');
  var model=create(function(){return performance.now();});
  global.fetch=observe(global.fetch.bind(global),model,function(input){try{var u=new URL(typeof input==='string'?input:input.url,location.href);return u.origin===location.origin&&endpoints.get(u.pathname);}catch(_){return false;}});
  var ns='http://www.w3.org/2000/svg';
  function svg(tag,attrs){var el=document.createElementNS(ns,tag);Object.keys(attrs).forEach(function(k){el.setAttribute(k,attrs[k]);});return el;}
  var selectedKey=null,queue=null,queueAt=0;
  var selector=document.getElementById('traffic-kind');
  global.addEventListener('schoolbell-queue-metrics',function(event){var v=event.detail;if(queue&&v&&queue.epoch!==v.epoch)selectedKey=null;queue=v&&v.available&&Array.isArray(v.bins)&&v.bins.length<=12&&Number.isFinite(v.now)?v:{available:false};queueAt=performance.now();render();});
  selector.addEventListener('change',function(){selectedKey=null;render();});
  function queueItems(){var key=Math.floor(queue.now/5),items=[];for(var k=key-11;k<=key;k++){var b=queue.bins.find(function(b){return b.key===k;}) || {};items.push({key:k,reads:b.depth || 0,commands:b.processed || 0,errors:b.failed || 0,wait_count:b.wait_count || 0,wait_sum:b.wait_sum || 0,wait_max:b.wait_max || 0,expired:b.expired || 0,running:b.running || 0});}return items;}
  function items(){return selector.value==='queue'&&queue&&queue.available?queueItems():model.snapshot().items;}
  var hint=document.getElementById('traffic-hint');
  function choose(index){var list=items();selectedKey=list[Math.max(0,Math.min(11,index))].key;render();}
  function point(event){var rect=chart.getBoundingClientRect();if(rect.width>0)choose(Math.round(((event.clientX-rect.left)*700/rect.width-20)/60));}
  chart.addEventListener('pointermove',point);chart.addEventListener('click',point);
  chart.addEventListener('focus',function(){if(selectedKey===null)choose(11);});
  chart.addEventListener('keydown',function(event){
    if(['ArrowLeft','ArrowRight','Home','End'].indexOf(event.key)<0)return;
    event.preventDefault();var list=items(),index=list.findIndex(function(b){return b.key===selectedKey;});
    choose(event.key==='Home'?0:event.key==='End'?11:(index<0?11:index)+(event.key==='ArrowLeft'?-1:1));
  });
  function render(){
    var isQueue=selector.value==='queue';
    document.getElementById('traffic-kind-label').textContent=isQueue?'Очередь исполнителя':'HTTP-запросы';
    ['traffic-mode','traffic-http-info','traffic-http-note','traffic-methods'].forEach(function(id){document.getElementById(id).hidden=isQueue;});
    ['queue-explanation','queue-legend'].forEach(function(id){document.getElementById(id).hidden=!isQueue;});
    if(isQueue&&(!queue||!queue.available||(queue.now-(queue.at===undefined?queue.now:queue.at))*1000+performance.now()-queueAt>15000||global.schoolbellSessionBlocked)){chart.replaceChildren();hint.textContent='Нет свежих измерений очереди. Отсутствие данных не означает пустую очередь.';document.getElementById('traffic-stats').textContent='Ожидаем штатный опрос состояния; дополнительных запросов нет.';document.getElementById('traffic-scale').textContent='';return;}
    var s=isQueue?{items:queueItems(),pending:0}:model.snapshot(),sum={reads:0,commands:0,errors:0,finished:0,total:0,max:0},peak=1;
    s.items.forEach(function(b){Object.keys(sum).forEach(function(k){if(k==='max')sum[k]=Math.max(sum[k],b[k] || 0);else sum[k]+=b[k] || 0;});peak=Math.max(peak,b.reads,b.commands);});
    chart.replaceChildren();
    var selected=s.items.find(function(b){return b.key===selectedKey;});
    if(selected){
      var index=s.items.indexOf(selected),age=Math.max(0,Math.floor(((isQueue?queue.now*1000:performance.now())-selected.key*5000)/1000));
      hint.textContent=(isQueue?'Очередь · ':'HTTP · ')+'Интервал '+Math.max(0,age-5)+'–'+age+' с назад'+(index===11?' (текущий)':'')+(isQueue?': глубина '+selected.reads+' · обработано '+selected.commands+' · отказов '+selected.errors+' · ожидание, максимум '+selected.wait_max+' мс':': всего '+(selected.reads+selected.commands)+' · чтение '+selected.reads+' · команды '+selected.commands+' · ошибки HTTP/сети '+selected.errors);
      chart.appendChild(svg('line',{x1:20+index*60,x2:20+index*60,y1:5,y2:120,class:'traffic-selection'}));
    }else{selectedKey=null;hint.textContent='Наведите на точку или нажмите её. Клавиатура: ← / →, Home / End.';}

    (isQueue?['reads','running','commands']:['reads','commands']).forEach(function(kind){var points=[];s.items.forEach(function(b,i){points.push((20+i*60)+','+(110-b[kind]/(isQueue&&kind!=='commands'?1:peak)*90));});chart.appendChild(svg('polyline',{points:points.join(' '),class:'traffic-'+kind,fill:'none','stroke-width':2}));
      s.items.forEach(function(b,i){var dot=svg('circle',{cx:20+i*60,cy:110-b[kind]/(isQueue&&kind!=='commands'?1:peak)*90,r:4,class:'traffic-'+kind});var title=svg('title',{});title.textContent=(isQueue?(kind==='reads'?'Глубина':kind==='running'?'Выполнялось':'Обработано'):(kind==='reads'?'Чтение':'Команды'))+': '+b[kind]+'; интервал '+(i+1)+' из 12';dot.appendChild(title);chart.appendChild(dot);});});
    if(isQueue){
      var count=0,total=0,max=0,expired=0;s.items.forEach(function(b){count+=b.wait_count;total+=b.wait_sum;max=Math.max(max,b.wait_max);expired+=b.expired;});
      document.getElementById('traffic-scale').textContent='Глубина: 0–1 · обработано: 0–'+peak+' за 5 с · последний интервал неполный';
      document.getElementById('traffic-stats').textContent=(queue.simulated?'Демо · ':'')+'Ожидает: '+queue.depth+' · Выполняется: '+queue.running+' · Обработано: '+sum.commands+' · Отказов: '+sum.errors+' · Истекло: '+expired+' · Ожидание до начала, среднее / максимум: '+(count?Math.round(total/count)+' / '+max+' мс':'нет обработанных ожиданий')+' · Возраст снимка: '+Math.floor(queue.now-(queue.at===undefined?queue.now:queue.at)+(performance.now()-queueAt)/1000)+' с';return;
    }
    var body=document.getElementById('traffic-method-rows');body.replaceChildren();
    if(!s.methods.length){var empty=document.createElement('tr'),cell=document.createElement('td');cell.colSpan=6;cell.textContent='В этом окне ещё нет запросов.';empty.appendChild(cell);body.appendChild(empty);}
    s.methods.forEach(function(g){var row=document.createElement('tr');
      [g.verb+' '+g.route+' · '+routes[g.route],g.reads+g.commands,g.finished,g.errors,g.pending,g.finished?Math.round(g.total/g.finished)+' / '+Math.round(g.max)+' мс':'—'].forEach(function(value){var cell=document.createElement('td');cell.textContent=String(value);row.appendChild(cell);});body.appendChild(row);
    });
    document.getElementById('traffic-scale').textContent='Шкала: 0–'+peak+' запросов за 5 с · последний интервал ещё заполняется';
    document.getElementById('traffic-stats').textContent='Чтение: '+sum.reads+' · Команды: '+sum.commands+' · Ошибки HTTP/сети: '+sum.errors+' · Ожидают HTTP: '+s.pending+' · До заголовков HTTP, среднее / максимум: '+(sum.finished?Math.round(sum.total/sum.finished)+' / '+Math.round(sum.max)+' мс':'нет завершённых запросов');
  }
  if(panel.dataset.session.indexOf('/demo-api/')!==-1)document.getElementById('traffic-mode').textContent='Демо: обращения к локальной модели, не измерение устройства.';
  render();setInterval(function(){if(!document.hidden&&!document.getElementById('panel-journal').hidden)render();},1000);
})(typeof window==='object'?window:globalThis);
