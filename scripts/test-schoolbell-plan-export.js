const fs=require('fs'),vm=require('vm'),assert=require('assert');
class El{constructor(){this.children=[];this.events={};this.dataset={url:'/export',token:'csrf'};this.disabled=false;this.textContent='';}addEventListener(k,f){this.events[k]=f;}append(...a){this.children.push(...a);}replaceChildren(...a){this.children=a;}querySelectorAll(){return this.children.flatMap(x=>x.children||[]).filter(x=>x.type==='checkbox');}remove(){}click(){if(!this.disabled)return this.events.click?.();}}
const ids=Object.fromEntries(['panel','plans','download','status'].map(x=>['plan-export-'+x,new El()]));let state={draft:{plans:[{id:'one',name:'Plan',start:'2030-09-01',end:'2030-09-03'}]},dirty:false,busy:false,reconcile:false,revision:'a'.repeat(64)},downloads=0,fetches=0,response;
const window={schoolbellEditor:{exportSnapshot:()=>JSON.parse(JSON.stringify(state))},addEventListener(){}};
const doc={getElementById:id=>ids[id],createElement:tag=>{const e=new El();if(tag==='a')e.click=()=>downloads++;return e;},createTextNode:s=>s,body:new El()};
const ctx={window,document:doc,Set,JSON,Number,Blob,AbortController,URL:{createObjectURL:()=> 'blob:one',revokeObjectURL(){}},setTimeout:()=>1,clearTimeout(){},setInterval(){},fetch:async(url,opt)=>{fetches++;assert.equal(url,'/export');assert.equal(JSON.parse(opt.body).revision,state.revision);return response;}};
vm.createContext(ctx);vm.runInContext(fs.readFileSync('ui/root/www/schoolbell-test/plan-export.js','utf8'),ctx);
const button=ids['plan-export-download'],box=ids['plan-export-plans'].querySelectorAll()[0];box.checked=true;box.events.change();assert(!button.disabled);
const bytes=new TextEncoder().encode('SBPLAN1\n'+'x'.repeat(74));
function reply(data=bytes){let once=false;return {ok:true,headers:{get:k=>k==='Content-Length'?String(bytes.length):'application/octet-stream'},body:{getReader:()=>({read:async()=>once?{done:true}:(once=true,{value:data,done:false}),cancel:async()=>{}})}};}
(async()=>{
response=reply();await button.click();assert.equal(downloads,1);assert(!button.disabled);
response=reply(bytes.slice(0,-1));await button.click();assert.equal(downloads,1);assert(ids['plan-export-status'].textContent.includes('прервалось'));assert(!button.disabled);
response={ok:false,json:async()=>({code:'conflict'})};await button.click();assert.equal(downloads,1);assert(ids['plan-export-status'].textContent.includes('изменился'));
state.dirty=true;await button.click();assert.equal(fetches,3);state.dirty=false;
response=reply();const read=response.body.getReader;response.body.getReader=()=>{const r=read();const f=r.read;r.read=async()=>{state.dirty=true;return f();};return r;};await button.click();assert.equal(downloads,1);
assert(!('automatic' in state));console.log('PASS export UI: selected saved revision, download, truncated/error recovery, dirty and stale snapshots; no activation or replay');
})().catch(e=>{console.error(e);process.exitCode=1;});
