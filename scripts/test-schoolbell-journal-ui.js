// Actual dashboard DOM handlers: pagination/filter/copy/local device timestamps.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..');
class E {
 constructor(){this.children=[];this.events={};this.dataset={};this.style={};this.disabled=false;this.textContent='';}
 addEventListener(k,f){this.events[k]=f;} setAttribute(k,v){this[k]=v;}
 appendChild(e){this.children.push(e);return e;}replaceChildren(){this.children=[];}
 select(){selected=this.value;}remove(){}focus(){}scrollIntoView(){}
 async click(){if(!this.disabled && this.events.click)await this.events.click();}
}
let selected='',copied='',fail=false,calls=0,copyDenied=false;
const ids=new Map(),get=k=>{if(!ids.has(k))ids.set(k,new E());return ids.get(k);};
const entries=Array.from({length:45},(_,i)=>({seq:i+1,time:1700000000+i,local_time:(i===43?'02':'03')+'.11.2026 10:00:'+String(i).padStart(2,'0')+' +0500',source:['user','module','system','module'][i%4],level:['error','warning','info'][i%3],action:i%3===0?'save_failed':'save_ok'}));
get('schedule-editor').dataset={journal:'journal',token:'token'};
const doc={hidden:true,addEventListener(){},getElementById:get,querySelectorAll:()=>[],querySelector:()=>new E(),createElement:()=>new E(),body:new E(),execCommand:()=>{copied=selected;return !copyDenied;}};
const win={addEventListener(){},isSecureContext:false};
const context={document:doc,window:win,navigator:{},sessionStorage:{getItem(){},setItem(){}},Date,Array,Math,Intl,URLSearchParams,AbortController,setInterval(){},setTimeout:()=>1,clearTimeout(){},fetch:async(url,options)=>{calls++;if(options.method==='POST'){assert.equal(options.body.get('action'),'clear');assert.equal(options.body.get('token'),'token');entries.length=0;}if(fail)throw Error('network');return {ok:true,json:async()=>({ok:true,entries})};}};
entries[44].bell={kind:'pre',due:'03.11.2026 10:53 +0500',plan:'Учебный план',schedule:'Будни'};
vm.runInNewContext(fs.readFileSync(path.join(root,'ui/root/www/schoolbell-test/dashboard.js'),'utf8'),context);
const eventRows=()=>get('journal-rows').children.filter(r=>r.className!=='journal-day');
(async()=>{
 let ready;win.schoolbellInitialReady=new Promise(resolve=>{ready=resolve;});
 const initial=get('journal-reload').click();assert.equal(calls,0);ready();await initial;assert.equal(calls,1);
 assert.equal(eventRows().length,20);
 assert.deepEqual(get('journal-rows').children.filter(r=>r.className==='journal-day').map(r=>r.children[0].textContent.slice(0,1)),['3','2','3']);
 assert(eventRows()[0].children[0].textContent.endsWith('03.11.2026 10:00:44'));
 assert(eventRows()[0].children[2].textContent.includes('Предзвонок по расписанию на 03.11.2026 10:53 · Учебный план · Будни'));
 await get('journal-last').click();assert.equal(get('journal-page').textContent,'41–45 из 45');assert(get('journal-last').disabled);
 await get('journal-first').click();assert(get('journal-first').disabled);
 assert(get('journal-prev').disabled);await get('journal-next').click();assert.equal(eventRows().length,20);
 await get('journal-next').click();assert.equal(eventRows().length,5);assert(get('journal-next').disabled);
 await get('journal-prev').click();assert.equal(get('journal-page').textContent,'21–40 из 45');
 await get('journal-prev').click();assert(get('journal-prev').disabled);
 await get('journal-errors').click();assert.equal(eventRows().length,15);assert(eventRows().every(r=>r.className==='journal-error'));
 await get('journal-warnings').click();assert(get('journal-page').textContent.includes('1–20 из 30'));
 assert(eventRows().every(r=>r.className!=='journal-info'));
 await get('journal-next').click();await get('journal-errors').click();
 assert(get('journal-prev').disabled && eventRows().length===15);
 assert(eventRows().every(r=>r.className==='journal-warning'));
 await get('journal-warnings').click();assert(get('journal-page').textContent.includes('1–20 из 45'));
 await get('journal-errors').click();
 await get('journal-source-system').click();assert(eventRows().every(r=>r.children[1].textContent!=='Пользователь' && r.className==='journal-error'));
 await get('journal-warnings').click();assert(eventRows().some(r=>r.className==='journal-warning'));
 await get('journal-source-user').click();assert(eventRows().every(r=>r.children[1].textContent==='Пользователь' && r.className!=='journal-info'));
 await get('journal-source-all').click();await get('journal-warnings').click();
 await get('journal-copy').click();assert.equal(copied.split('\n').length,45);assert(copied.includes('03.11.2026 10:00:44 +0500'));
 assert.equal(calls,1,'pagination/filter/copy must not fetch');
 fail=true;await get('journal-reload').click();assert.equal(eventRows().length,15);assert(get('journal-status').textContent.includes('устаревшими'));
 copyDenied=true;await get('journal-copy').click();assert(get('journal-status').textContent.includes('не разрешил'));
 win.isSecureContext=true;context.navigator.clipboard={writeText:async text=>copied=text};await get('journal-copy').click();assert.equal(copied.split('\n').length,45);
 fail=false;win.confirm=()=>false;const reads=calls;await get('journal-clear').click();assert.equal(calls,reads);assert.equal(entries.length,45);
 win.confirm=()=>true;await get('journal-clear').click();assert.equal(entries.length,0);assert.equal(eventRows().length,0);assert(get('journal-clear').disabled);
await get('journal-reload').click();assert.equal(eventRows().length,0);assert(get('journal-copy').disabled);assert(get('journal-prev').disabled && get('journal-next').disabled);
 const controls=fs.readFileSync(path.join(root,'ui/root/www/schoolbell-test/controls.js'),'utf8');assert(controls.includes("'🔇':'🔊'"));
 console.log('PASS journal UI: pages, errors, whole-history copy HTTP/HTTPS, denial, stale rows, empty list and device time');
})().catch(e=>{console.error(e);process.exit(1);});
