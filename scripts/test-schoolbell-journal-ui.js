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
const entries=Array.from({length:45},(_,i)=>({seq:i+1,time:1700000000+i,local_time:'DEVICE '+i+' +0500',source:'user',level:i%3===0?'error':'info',action:i%3===0?'save_failed':'save_ok'}));
get('schedule-editor').dataset={journal:'journal'};
const doc={hidden:true,addEventListener(){},getElementById:get,querySelectorAll:()=>[],querySelector:()=>new E(),createElement:()=>new E(),body:new E(),execCommand:()=>{copied=selected;return !copyDenied;}};
const win={addEventListener(){},isSecureContext:false};
const context={document:doc,window:win,navigator:{},sessionStorage:{getItem(){},setItem(){}},Date,Array,Math,Intl,AbortController,setInterval(){},setTimeout:()=>1,clearTimeout(){},fetch:async()=>{calls++;if(fail)throw Error('network');return {ok:true,json:async()=>({ok:true,entries})};}};
vm.runInNewContext(fs.readFileSync(path.join(root,'ui/root/www/schoolbell-test/dashboard.js'),'utf8'),context);
(async()=>{
 await get('journal-reload').click();assert.equal(calls,1);assert.equal(get('journal-rows').children.length,20);
 assert(get('journal-rows').children[0].children[0].textContent.includes('DEVICE 44 +0500'));
 assert(get('journal-prev').disabled);await get('journal-next').click();assert.equal(get('journal-rows').children.length,20);
 await get('journal-next').click();assert.equal(get('journal-rows').children.length,5);assert(get('journal-next').disabled);
 await get('journal-first').click();assert(get('journal-first').disabled);assert.equal(get('journal-rows').children.length,20);
 await get('journal-last').click();assert(get('journal-last').disabled);assert.equal(get('journal-rows').children.length,5);
 await get('journal-errors').click();assert.equal(get('journal-rows').children.length,15);assert(get('journal-rows').children.every(r=>r.className==='journal-error'));
 await get('journal-copy').click();assert.equal(copied.split('\n').length,45);assert(copied.includes('DEVICE 44 +0500'));
 assert.equal(calls,1,'pagination/filter/copy must not fetch');
 fail=true;await get('journal-reload').click();assert.equal(get('journal-rows').children.length,15);assert(get('journal-status').textContent.includes('устаревшими'));
 copyDenied=true;await get('journal-copy').click();assert(get('journal-status').textContent.includes('не разрешил'));
 win.isSecureContext=true;context.navigator.clipboard={writeText:async text=>copied=text};await get('journal-copy').click();assert.equal(copied.split('\n').length,45);
 fail=false;entries.length=0;await get('journal-reload').click();assert.equal(get('journal-rows').children.length,0);assert(get('journal-copy').disabled);assert(get('journal-prev').disabled && get('journal-next').disabled);
 const controls=fs.readFileSync(path.join(root,'ui/root/www/schoolbell-test/controls.js'),'utf8');assert(controls.includes("'🔇 Без звука':'🔊 Без звука'"));
 console.log('PASS journal UI: pages, errors, whole-history copy HTTP/HTTPS, denial, stale rows, empty list and device time');
})().catch(e=>{console.error(e);process.exit(1);});
