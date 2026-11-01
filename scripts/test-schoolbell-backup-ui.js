// Exercise the shipped UI with controlled network and timers, without a router.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('ui/root/www/schoolbell-test/backup.js','utf8');
const flush=async()=>{for(let i=0;i<100;i++)await Promise.resolve();};
function fixture(statusBusy=0,open=true){
 const elements=new Map(),timers=new Map();let next=0;
 function element(){return {disabled:false,hidden:false,files:[],dataset:{url:'backup',token:'test'},events:{},addEventListener(k,f){this.events[k]=f;},click(){if(!this.disabled)return this.events.click?.();}};}
 for(const id of ['panel','status','file','download','restore','resume','refresh'])elements.set('backup-'+id,element());
 const x={statusBusy,mode:'ok',saved:0,created:0,revoked:0,calls:[],pending:false,get:id=>elements.get('backup-'+id)};
 const valid=new Blob(['SBBACKUP1\npayload']);
 const fetch=async(url,o={})=>{
  x.calls.push(url);if(o.method==='POST'){assert(o.headers.Authorization==='Bearer test');return {ok:true,json:async()=>({ok:false,code:'busy'})};}if(url.endsWith('status')){if(x.statusBusy>0){x.statusBusy--;return {ok:true,json:async()=>({ok:false,code:'busy'})};}if(x.badStatus)throw Error('status unavailable');return {ok:true,json:async()=>({ok:true,pending:x.pending,operation_id:'pending-id'})};}
  assert(url.endsWith('download'),'unexpected mutation '+url);x.signal=o.signal;if(x.downloadBusy>0){x.downloadBusy--;return {ok:false,json:async()=>({ok:false,code:'busy'})};}
  if(x.mode==='headers')return new Promise(resolve=>x.release=()=>resolve({ok:true,blob:async()=>valid}));
  if(x.mode==='network')throw TypeError('network unavailable');
  if(x.mode==='http')return {ok:false,json:async()=>({ok:false,code:'busy'})};
  return {ok:true,blob:()=>x.mode==='body'?new Promise(resolve=>x.release=()=>resolve(valid)):x.mode==='disconnect'?Promise.reject(TypeError('body interrupted')):Promise.resolve(x.mode==='invalid'?new Blob(['bad']):valid)};
 };
 const ctx={document:{getElementById:id=>elements.get(id),createElement:()=>({click(){x.saved++;}})},fetch,AbortController,Blob,Uint8Array,Date,URL:{createObjectURL(){x.created++;return 'blob:test';},revokeObjectURL(){x.revoked++;}},crypto:{getRandomValues:a=>a},confirm:()=>{if(x.allowRestore)return true;throw Error('unexpected restore');},location:{reload(){throw Error('unexpected reload');}},setTimeout(f,ms){if(ms<=1000){Promise.resolve().then(f);return 0;}const id=++next;timers.set(id,{f,ms});return id;},clearTimeout:id=>timers.delete(id)};
 vm.runInNewContext(source,ctx);if(open){x.get('panel').open=true;x.get('panel').events.toggle();}x.expire=ms=>{for(const [id,t] of [...timers])if(t.ms===ms){timers.delete(id);t.f();}};x.timers=timers;return x;
}
(async()=>{
 let closed=fixture(0,false);await flush();assert.equal(closed.calls.length,0,'closed backup must not contend with startup media reads');assert(closed.get('download').disabled && closed.get('restore').disabled);closed.get('panel').open=true;closed.get('panel').events.toggle();await flush();assert.equal(closed.calls.length,1);assert(!closed.get('download').disabled);closed.get('panel').open=false;closed.get('panel').events.toggle();await flush();assert.equal(closed.calls.length,1);closed.pending=true;closed.get('panel').open=true;closed.get('panel').events.toggle();await flush();assert.equal(closed.calls.length,2);assert(!closed.get('resume').hidden && closed.get('download').disabled);
 console.log('PASS closed backup sends no startup request; each opening checks current state, close sends none');
 let initial=fixture(2);await flush();assert(!initial.get('download').disabled && initial.calls.length===3);initial=fixture(10);await flush();assert(initial.calls.length===4 && initial.get('download').disabled && !initial.get('refresh').disabled);
 let x=fixture();await flush();assert(!x.get('download').disabled);await x.get('download').click();assert(x.saved===1);assert(!x.signal.aborted);assert(![...x.timers.values()].some(t=>t.ms===180000));x.expire(30000);assert(x.revoked===1);
 x=fixture();await flush();x.statusBusy=2;await x.get('refresh').click();assert(!x.get('download').disabled);x.downloadBusy=2;await x.get('download').click();assert(x.saved===1 && x.calls.filter(v=>v.endsWith('download')).length===3);x.downloadBusy=10;await x.get('download').click();assert(x.saved===1 && x.get('download').disabled && !x.get('refresh').disabled);assert(x.calls.filter(v=>v.endsWith('download')).length===7);assert(x.calls.every(v=>!/restore|resume/.test(v)));console.log('PASS bounded status/download busy retries; exhaustion restores controls without any POST');
 console.log('PASS completed backup, timer cleared, object URL released');
 for(const mode of ['headers','body','network','disconnect','http','invalid']){
  x=fixture();await flush();x.mode=mode;const task=x.get('download').click();await flush();
  if(['headers','body'].includes(mode)){assert(x.get('refresh').disabled);x.expire(180000);}
  await task;assert(!x.get('refresh').disabled);assert(x.get('download').disabled && x.get('restore').disabled);assert(x.saved===0 && x.created===0);
  if(x.release){assert(x.signal.aborted);x.release();await flush();assert(x.saved===0,'late completion saved after timeout');}
  x.badStatus=true;await x.get('refresh').click();assert(x.get('download').disabled);assert(!x.get('refresh').disabled);
  x.badStatus=false;x.mode='ok';await x.get('refresh').click();assert(!x.get('download').disabled);await x.get('download').click();assert(x.saved===1);
 }
 console.log('PASS stalled headers/body, disconnect, HTTP and invalid file: controls recover, explicit status check, no late download or retry');
 x=fixture();await flush();x.mode='network';await x.get('download').click();x.pending=true;await x.get('refresh').click();assert(x.get('download').disabled && !x.get('resume').hidden && !x.get('resume').disabled);
 assert(x.calls.every(url=>!/restore|resume/.test(url)));console.log('PASS pending restore remains explicit; no mutation triggered by download failure');
 x=fixture();await flush();x.allowRestore=true;x.get('file').files=[new Blob(['archive'])];x.get('file').events.change();await x.get('restore').click();assert(x.calls.filter(v=>v.includes('action=restore')).length===1);console.log('PASS busy restore POST is sent exactly once');
})().catch(e=>{console.error(e);process.exitCode=1;});
