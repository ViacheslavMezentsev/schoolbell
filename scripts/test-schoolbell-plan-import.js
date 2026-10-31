const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('ui/root/www/schoolbell-test/plan-import.js','utf8');
function fixture(){
 const nodes=new Map(),calls=[],listeners={},storage=new Map();let reloads=0,locked=false,reply;
 class Element{constructor(){this.dataset={};this.children=[];this.events={};this.files=[];this.disabled=false;this.hidden=false;this.value='';}addEventListener(n,f){this.events[n]=f;}appendChild(e){this.children.push(e);}replaceChildren(...v){this.children=v;}querySelectorAll(){return this.children.flatMap(l=>l.children);}async click(){if(!this.disabled)await this.events.click?.();}}
 function get(id){if(!nodes.has(id))nodes.set(id,new Element());return nodes.get(id);}
 get('plan-import-panel').dataset={url:'/plan-import',token:'csrf'};
 let snapshot={loaded:true,dirty:false,busy:false,reconcile:false,revision:'r1'};
 const editor={snapshot:()=>({...snapshot,busy:snapshot.busy||locked}),lock:()=>{if(locked)return false;locked=true;return true;},unlock:()=>{locked=false;},reloadImported:async()=>{reloads++;locked=false;snapshot.revision='r2';}};
 const fetch=async(url,opts)=>{const action=new URL(url,'http://device').searchParams.get('action');const id=new URL(url,'http://device').searchParams.get('operation_id');calls.push({action,opts});let value=reply?await reply(action,id):action==='upload'?{ok:true,state:'validated',plans:[{id:'p',name:'Учебный'}],schedules:[{id:'s',name:'День'}]}:action==='preview'?{ok:true,state:'preview',preview_token:'a'.repeat(64),mapping:{plans:[{name:'Учебный'}],media:[{title:'Тест',slot:'test'}]}}:{ok:true,state:'committed',result:{automatic_enabled:false}};return {ok:true,status:200,json:async()=>({operation_id:id,code:'ok',...value})};};
 const win={schoolbellEditor:editor};
 vm.runInNewContext(source,{window:win,document:{getElementById:get,createElement:()=>new Element()},fetch,URL,AbortController,crypto:require('node:crypto').webcrypto,Uint8Array,FormData:class{append(){}},sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},setInterval:f=>{listeners.tick=f;},setTimeout:()=>1,clearTimeout(){},confirm:()=>true,console});
 return {get,calls,win,snapshot,setReply:f=>{reply=f;},tick:()=>listeners.tick(),reloads:()=>reloads};
}
(async()=>{
 const f=fixture();f.get('plan-import-file').files=[{size:300}];f.tick();await f.get('plan-import-upload').click();assert.equal(f.calls.length,1);assert.equal(f.calls[0].action,'upload');assert.equal(f.calls[0].opts.headers.Authorization,'Bearer csrf');assert.equal(f.get('plan-import-names').children.length,2);
 await f.get('plan-import-preview').click();assert.equal(f.get('plan-import-commit').disabled,false);f.snapshot.dirty=true;f.tick();assert.equal(f.get('plan-import-commit').disabled,true);f.snapshot.dirty=false;f.snapshot.revision='new';f.tick();assert.equal(f.get('plan-import-commit').disabled,true);
 await f.get('plan-import-preview').click();await f.get('plan-import-commit').click();assert.equal(f.reloads(),1);assert.equal(f.calls.filter(x=>x.action==='commit').length,1);assert.match(f.get('plan-import-status').textContent,/автозвонки выключены/);
 assert(!f.calls.some(x=>/automatic|play|clock/.test(x.action)));
 const g=fixture();g.get('plan-import-file').files=[{size:200}];g.tick();await g.get('plan-import-upload').click();await g.get('plan-import-preview').click();g.setReply(()=>{throw Error('connection lost');});await g.get('plan-import-commit').click();assert.equal(g.calls.filter(x=>x.action==='commit').length,1);assert.equal(g.reloads(),0);assert.match(g.get('plan-import-status').textContent,/Исход не подтверждён/);assert.equal(g.get('plan-import-check').disabled,false);assert.equal(g.get('plan-import-commit').disabled,true);
 console.log('PASS import UI: explicit upload/preview/commit, dirty/revision invalidation, CSRF, no command replay or activation, unknown outcome and retained editor');
})().catch(e=>{console.error(e);process.exit(1);});
