(()=>{'use strict';
const panel=document.getElementById('backup-panel');if(!panel)return;
const get=id=>document.getElementById('backup-'+id),out=get('status'),file=get('file');let busy=false,pending=null,needsCheck=true;
const url=panel.dataset.url,token=panel.dataset.token;
const errors={busy:'Сейчас выполняется другая операция. Повторите проверку позже.',automatic_enabled:'Сначала отключите автозвонки.',space:'Недостаточно места с учётом временных файлов и запаса.',rejected:'Копия отклонена: проверьте файл, его полноту, часовой пояс и свободное место.',restore_pending:'Восстановление не завершено. Звонки заблокированы; нажмите «Проверить состояние», затем продолжите восстановление.',restore_uncertain:'Результат не подтверждён. Проверьте состояние перед повторением.',storage:'Не удалось проверить хранилище. Проверьте состояние; не включайте звонки.'};
function buttons(){get('download').disabled=busy||needsCheck||!!pending;get('restore').disabled=busy||needsCheck||!!pending||!file.files.length;get('resume').hidden=!pending;get('resume').disabled=busy||needsCheck;get('refresh').disabled=busy;file.disabled=busy||!!pending;}
const BUSY_DELAYS=[200,500,1000];
async function busyPause(attempt,signal){out.textContent='Хранилище занято другим запросом. Повторяем чтение…';await new Promise(resolve=>setTimeout(resolve,BUSY_DELAYS[attempt]));if(signal.aborted)throw new Error('Время ожидания истекло. Проверьте состояние.');}
async function request(action,options={}){const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),180000);try{for(let attempt=0;;attempt++){const response=await fetch(url+'?action='+action, Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal},options));if(!response.ok)throw new Error('HTTP '+response.status);const v=await response.json();if(!v.ok && v.code==='busy' && action==='status' && !options.method && attempt<BUSY_DELAYS.length){await busyPause(attempt,abort.signal);continue;}if(!v.ok)throw new Error(errors[v.code]||'Операция не подтверждена.');return v;}}finally{clearTimeout(timer);}}
async function check(){needsCheck=true;const v=await request('status');pending=v.pending?v.operation_id:null;needsCheck=false;out.textContent=pending?errors.restore_pending:'Незавершённого восстановления нет.';buttons();return v;}
async function run(fn){if(busy)return;busy=true;buttons();try{await fn();}catch(e){out.textContent=e.message+' Обновите состояние, если запрос прервался.';}finally{busy=false;buttons();}}
function op(){const a=new Uint8Array(16);crypto.getRandomValues(a);return Array.from(a,x=>x.toString(16).padStart(2,'0')).join('');}
get('refresh').addEventListener('click',()=>run(check));file.addEventListener('change',buttons);
// One deadline covers headers, the complete body and the format check.
const DOWNLOAD_TIMEOUT_MS=180000;
async function downloadBlob(){
 const abort=new AbortController();let timer;
 const deadline=new Promise((_,reject)=>{timer=setTimeout(()=>{reject(new Error('Время скачивания истекло (180 с). Проверьте состояние перед повтором.'));abort.abort();},DOWNLOAD_TIMEOUT_MS);});
 const transfer=(async()=>{
  for(let attempt=0;;attempt++){
  const response=await fetch(url+'?action=download',{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});
  if(!response.ok){let v;try{v=await response.json();}catch(_){}if(v && v.code==='busy' && attempt<BUSY_DELAYS.length){await busyPause(attempt,abort.signal);continue;}throw new Error(errors[v&&v.code]||'Копия не создана.');}
  const blob=await response.blob();if(blob.size>2162816||!(await blob.slice(0,10).text()).startsWith('SBBACKUP1\n'))throw new Error('Ответ не является резервной копией.');
  return blob;}
 })();
 try{return await Promise.race([transfer,deadline]);}finally{clearTimeout(timer);}
}
get('download').addEventListener('click',()=>run(async()=>{
 if(needsCheck||pending)return;
 out.textContent='Создаём копию…';let blob;
 try{blob=await downloadBlob();}catch(e){needsCheck=true;throw e;}
 const a=document.createElement('a'),link=URL.createObjectURL(blob);a.href=link;a.download='schoolbell-'+new Date().toISOString().slice(0,10)+'.sbb';a.click();setTimeout(()=>URL.revokeObjectURL(link),30000);out.textContent='Копия скачана. Храните её отдельно от устройства.';
}));
async function restore(resume){if(needsCheck)return;const selected=file.files[0];if(!resume&&(!selected||selected.size<1||selected.size>2162816))throw new Error('Выберите копию .sbb размером до 2,07 МиБ.');if(!confirm(resume?'Продолжить восстановление? Автозвонки останутся выключенными.':'Заменить сохранённые настройки, планы и пользовательские мелодии? Несохранённые правки страницы будут потеряны. Автозвонки останутся выключенными.'))return;
const id=resume?pending:op();out.textContent='Проверяем и восстанавливаем. Не закрывайте страницу…';await request((resume?'resume':'restore')+'&operation='+id,{method:'POST',headers:{'Content-Type':'application/octet-stream','Authorization':'Bearer '+token},body:resume?'':selected});pending=null;out.textContent='Восстановлено. Автозвонки выключены. Обновляем страницу…';location.reload();}
get('restore').addEventListener('click',()=>run(()=>restore(false)));get('resume').addEventListener('click',()=>run(()=>restore(true)));
if(url.includes('demo-api')){for(const id of ['download','restore','resume','refresh','file'])get(id).disabled=true;out.textContent='Резервная копия устройства доступна в установленном модуле. Демо хранит только данные этого браузера.';}else run(check);
})();
