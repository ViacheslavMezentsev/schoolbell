(function () {
  'use strict';
  var panel=document.getElementById('session-panel'),root=document.getElementById('schedule-editor');
  var status=document.getElementById('session-status'),warning=document.getElementById('session-warning');
  var check=document.getElementById('session-check'),logout=document.getElementById('session-logout');
  var login=document.getElementById('session-login');
  function navigate(){if(window.schoolbellEditor && !window.schoolbellEditor.prepareNavigation()){status.hidden=false;status.textContent='Не удалось сохранить правки перед входом. Страница оставлена открытой.';return false;}location.assign(login.href);return true;}
  login.addEventListener('click',function(e){e.preventDefault();navigate();});
  var countdown=document.getElementById('session-countdown'),duration=document.getElementById('session-duration');
  var endpoint=new URL(panel.dataset.session,location.href),base=endpoint.pathname.replace(/\/session$/,'');
  if(endpoint.pathname.includes('/demo-api/')){
    status.textContent='Демо: вход LuCI и выход недоступны. Данные хранятся в этом браузере.';
    document.getElementById('session-login').hidden=true;check.disabled=true;logout.disabled=true;duration.disabled=true;
    countdown.textContent='Демо: сеанс устройства не используется.';return;
  }
  var rawFetch=window.fetch.bind(window),user=panel.dataset.user,token=root.dataset.token;
  var blocked=false,checking=false,leaving=false,epoch=0,controllers=new Set(),minutes=30;
  try{var saved=Number(localStorage.getItem('schoolbell-idle-minutes'));if([1,5,15,30,60,120].includes(saved))minutes=saved;}catch(_){}
  duration.value=String(minutes);
  var lastMono=performance.now(),lastWall=Date.now();
  function activity(){lastMono=performance.now();lastWall=Date.now();}
  function lose(message){
    blocked=true;window.schoolbellSessionBlocked=true;epoch++;controllers.forEach(function(c){c.abort();});controllers.clear();
    warning.hidden=true;logout.hidden=true;logout.disabled=true;login.hidden=false;status.hidden=false;status.textContent=message;
    window.dispatchEvent(new CustomEvent('schoolbell-session-lost'));

  }
  function isAuth(response){return response.status===401 || response.status===403 || response.type==='opaqueredirect' || (response.status>=300 && response.status<400) || /text\/html/i.test(response.headers.get('Content-Type') || '');}
  function scoped(input){var u=new URL(typeof input==='string'?input:input.url,location.href);return u.origin===endpoint.origin && (u.pathname===base || u.pathname.startsWith(base+'/'));}
  window.fetch=async function(input,options){
    if(!scoped(input))return rawFetch(input,options);
    if(blocked || leaving)throw Error('schoolbell_session_required');
    var current=epoch,opts=Object.assign({},options),controller=new AbortController(),external=opts.signal;
    function abort(){controller.abort();}
    if(external){if(external.aborted)abort();else external.addEventListener('abort',abort,{once:true});}
    controllers.add(controller);opts.signal=controller.signal;opts.redirect='manual';opts.credentials='same-origin';opts.cache='no-store';
    // Modules may retain the original token. Replace it only on this same-origin module API.
    if(String(opts.method || 'GET').toUpperCase()==='POST'){
      if(opts.body instanceof URLSearchParams){opts.body=new URLSearchParams(opts.body);if(opts.body.has('token'))opts.body.set('token',token);}
      opts.headers=new Headers(opts.headers || {});
      if(opts.headers.has('Authorization'))opts.headers.set('Authorization','Bearer '+token);
    }
    try{
      var response=await rawFetch(input,opts);
      if(current!==epoch)throw Error('schoolbell_session_changed');
      if(isAuth(response)){lose('Сеанс завершён. Войдите снова.');throw Error('schoolbell_session_required');}
      return response;
    }finally{controllers.delete(controller);if(external)external.removeEventListener('abort',abort);}
  };
  async function sessionRequest(options){
    var controller=new AbortController(),timer;
    var deadline=new Promise(function(_,reject){timer=setTimeout(function(){controller.abort();reject(Error('timeout'));},15000);});
    var transfer=(async function(){
      var response=await rawFetch(endpoint.href,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'manual',signal:controller.signal},options));
      if(response.ok && !isAuth(response))response.sessionValue=await response.json();
      return response;
    })();
    try{return await Promise.race([transfer,deadline]);}finally{clearTimeout(timer);}
  }
  check.addEventListener('click',async function(){
    if(checking || leaving)return;checking=true;check.disabled=true;var observed=epoch;
    try{
      var response=await sessionRequest();
      if(isAuth(response)){lose('Сеанс завершён. Нажмите «Войти».');return;}
      if(!response.ok)throw Error('unavailable');
      if(observed!==epoch || leaving)return;
      var value=response.sessionValue;
      if(!value.ok || typeof value.token!=='string' || !/^[a-zA-Z0-9]{16,128}$/.test(value.token))throw Error('response');
      if(value.user!==user){lose('Вход выполнен другим пользователем. Эта вкладка не возобновляет доступ; локальные правки остаются здесь.');return;}
      token=value.token;root.dataset.token=token;blocked=false;window.schoolbellSessionBlocked=false;window.dispatchEvent(new CustomEvent('schoolbell-session-restored'));logout.disabled=false;warning.hidden=true;activity();
      status.textContent='Вход подтверждён: '+user+'. Правки не заменены. Сверьте черновик с устройством; команды не повторялись.';
      // No replay, reload, save, activation or clock operation on reconnect.
    }catch(_){status.textContent='Не удалось проверить сеанс. Правки остаются здесь. Проверьте связь и повторите проверку.';}
    finally{checking=false;check.disabled=false;}
  });
  async function leave(automatic){
    if(leaving || blocked)return;
    if(!automatic && !window.confirm('Выйти из LuCI? Несохранённые правки будут временно сохранены в этой вкладке браузера.'))return;
    if(!automatic && window.schoolbellEditor && !window.schoolbellEditor.prepareNavigation()){status.hidden=false;status.textContent='Не удалось сохранить правки. Выход отменён.';return;}
    leaving=true;check.disabled=true;
    lose(automatic?'Время бездействия истекло. Завершаем сеанс LuCI…':'Завершаем сеанс LuCI…');
    try{
      var response=await sessionRequest({method:'POST',body:new URLSearchParams({token:token,action:'logout'})});
      if(isAuth(response)){status.textContent='Сеанс уже недоступен. Правки остаются в этой вкладке.';return;}
      if(!response.ok)throw Error('logout');var value=response.sessionValue;if(!value.ok || value.logged_out!==true)throw Error('logout');
      status.textContent='Сеанс завершён.';if(!automatic)navigate();
    }catch(_){status.textContent='Не удалось подтвердить выход. Доступ к управлению приостановлен. Нажмите «Войти», чтобы вернуться; правки остаются в этой вкладке.';}
    finally{leaving=false;check.disabled=false;}
  }
  logout.addEventListener('click',function(){return leave(false);});
  ['pointerdown','keydown','input','wheel','touchstart'].forEach(function(type){document.addEventListener(type,function(e){if(e.isTrusted && !blocked && !leaving)activity();},{passive:true});});
  duration.addEventListener('change',function(){var n=Number(duration.value);if(![1,5,15,30,60,120].includes(n))return;minutes=n;try{localStorage.setItem('schoolbell-idle-minutes',String(n));}catch(_){}activity();draw();});
  function draw(){
    if(blocked || leaving)return;
    var elapsed=Math.max(0,performance.now()-lastMono,Date.now()-lastWall),seconds=Math.max(0,Math.ceil((minutes*60000-elapsed)/1000));

    if(seconds===0)leave(true);
  }
  draw();setInterval(draw,1000);
}());
