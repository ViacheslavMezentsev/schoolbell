(function(){
'use strict';
const panel=document.getElementById('plan-export-panel');if(!panel)return;
const list=document.getElementById('plan-export-plans'),button=document.getElementById('plan-export-download'),status=document.getElementById('plan-export-status');
let busy=false,shown='',selected=new Set();
const snapshot=()=>window.schoolbellEditor?.exportSnapshot();
function ready(s){return s&&s.draft&&!s.dirty&&!s.busy&&!s.reconcile&&!window.schoolbellSessionBlocked;}
function render(){const s=snapshot(),plans=s?.draft?.plans||[],key=JSON.stringify(plans.map(p=>[p.id,p.name,p.start,p.end]));
 if(key!==shown){shown=key;selected=new Set([...selected].filter(id=>plans.some(p=>p.id===id)));list.replaceChildren();
 for(const p of plans){const label=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.checked=selected.has(p.id);input.addEventListener('change',()=>{if(input.checked)selected.add(p.id);else selected.delete(p.id);render();});label.append(input,document.createTextNode(' '+p.name+' · '+p.start+' — '+p.end));list.append(label);}}
 button.disabled=busy||!ready(s)||selected.size===0;for(const input of list.querySelectorAll('input'))input.disabled=busy||!ready(s);
}
button.addEventListener('click',async()=>{const s=snapshot();if(busy||!ready(s)||!selected.size)return;const signature=JSON.stringify(s);busy=true;render();status.textContent='Готовим файл со всеми зависимостями…';
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),180000);let reader;
 try{
  const response=await fetch(panel.dataset.url,{method:'POST',credentials:'same-origin',cache:'no-store',redirect:'error',signal:controller.signal,headers:{'Content-Type':'application/json',Authorization:'Bearer '+panel.dataset.token},body:JSON.stringify({selected:[...selected],revision:s.revision})});
  if(!response.ok){const e=await response.json();const messages={busy:'Хранилище занято. Повторите скачивание позже.',conflict:'Черновик изменился. Сверьте его с устройством.',automatic_enabled:'Сначала выключите автозвонки.',space:'Недостаточно временного места.',dependency:'Не найдена мелодия выбранного плана.',timezone:'Проверьте часовой пояс.'};throw Error(messages[e.code]||'Экспорт недоступен: '+(e.code||response.status));}
  const length=Number(response.headers.get('Content-Length'));if(response.headers.get('Content-Type')?.split(';')[0]!=='application/octet-stream'||!Number.isInteger(length)||length<82||length>2125906)throw Error('Ответ не является файлом плана');
  reader=response.body.getReader();const chunks=[];let size=0;
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>length)throw Error('Размер ответа превышен');chunks.push(part.value);}
  if(size!==length)throw Error('Скачивание прервалось');const blob=new Blob(chunks,{type:'application/octet-stream'});if(await blob.slice(0,8).text()!=='SBPLAN1\n')throw Error('Неверный формат ответа');
  if(window.schoolbellSessionBlocked||JSON.stringify(snapshot())!==signature)throw Error('Данные или сеанс изменились. Повторите скачивание после проверки черновика');
  const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='schoolbell-plans.sbp';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);status.textContent='Файл .sbp скачан. Данные и автозвонки не изменены.';
 }catch(e){status.textContent=e.name==='AbortError'?'Время скачивания истекло. Можно повторить; данные не изменены.':e.message;}finally{if(reader)try{await reader.cancel();}catch(_){}clearTimeout(timer);busy=false;render();}
});
window.addEventListener('schoolbell-editor-state',render);setInterval(render,1000);render();
}());
