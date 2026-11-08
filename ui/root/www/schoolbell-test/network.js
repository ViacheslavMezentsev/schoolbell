(function(){
'use strict';
var root=document.getElementById('schedule-editor'),enabled=document.getElementById('network-enabled'),host=document.getElementById('network-host'),save=document.getElementById('network-save'),result=document.getElementById('network-result');
var current=null,busy=false,dirty=false;
function valid(s){return typeof s==='string' && s.length>0 && s.length<=253 && s.split('.').every(function(p){return /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(p);});}
function controls(){var blocked=!current || busy || !!window.schoolbellSessionBlocked;enabled.disabled=blocked;host.disabled=blocked;save.disabled=blocked || !dirty || !valid(host.value);}
function line(id,prefix,value){
 var el=document.getElementById(id);if(!el)return;value=value || {state:'unknown'};
 var names={available:'доступен',unconfirmed:'не подтверждён',checking:'проверка…',unknown:'нет данных',disabled:'проверка выключена',synced:'синхронизирован',waiting:'ожидание синхронизации',stopped:'служба остановлена',demo:'демо'};
 var text=names[value.state] || names.unknown;if(prefix==='NTP' && value.state==='disabled')text='выключен';
 el.textContent=prefix+' · '+text;el.dataset.tone=['unconfirmed','stopped'].includes(value.state)?'warning':'normal';
 var info=prefix==='Интернет'?'Ответ проверяемого адреса; отсутствие ответа не доказывает отсутствие Интернета.':'Состояние синхронизации часов Школьника. Запущенная служба сама по себе не подтверждает синхронизацию.';
 if(value.host)info+=' Адрес: '+value.host+'.';
 if(typeof value.age_seconds==='number')info+=' Давность '+(prefix==='Интернет'?'проверки':'события NTP')+': '+value.age_seconds+' с.';
 el.title=value.state==='demo'?'Демонстрация: состояние оборудования не проверяется.':info;
}
window.schoolbellNetworkRender=function(snapshot){
 line('network-internet','Интернет',snapshot && snapshot.internet);line('network-ntp','NTP',snapshot && snapshot.ntp);
 if(snapshot && snapshot.config){current=snapshot.config;if(!dirty && !busy){enabled.checked=current.enabled;host.value=current.host;}}
 else current=null;
 controls();
};
function change(){dirty=!!current && (enabled.checked!==current.enabled || host.value!==current.host);controls();}
enabled.addEventListener('change',change);host.addEventListener('input',change);
save.addEventListener('click',async function(){
 if(save.disabled)return;busy=true;controls();result.textContent='Сохраняем…';
 var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},15000);
 try{var r=await fetch(root.dataset.network,{method:'POST',credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal,body:new URLSearchParams({token:root.dataset.token,enabled:String(enabled.checked),host:host.value})});
  if(!r.ok)throw Error();var data=await r.json();if(!data.ok)throw Error();
  dirty=false;busy=false;window.schoolbellNetworkRender(data.network);result.textContent='Сохранено. Следующая проверка — в течение минуты.';
 }catch(_){result.textContent='Сохранение не подтверждено. Обновите страницу и проверьте настройку.';}
 finally{clearTimeout(timer);busy=false;controls();}
});
window.addEventListener('schoolbell-session-lost',function(){current=null;window.schoolbellNetworkRender(null);});
}());
