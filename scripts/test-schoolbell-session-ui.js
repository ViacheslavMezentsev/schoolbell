const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('ui/root/www/schoolbell-test/session.js','utf8');
function setup(demo=false){
 const ids={},events={},docEvents={},intervals=[],stored={},calls=[];let now=0,reply;
 for(const id of ['session-panel','schedule-editor','session-status','session-warning','session-check','session-logout','session-countdown','session-duration','session-login'])ids[id]={dataset:{},events:{},addEventListener(t,f){this.events[t]=f;},textContent:'',disabled:false};
 ids['session-panel'].dataset={session:demo?'./demo-api/session':'/cgi-bin/luci/admin/schoolbell/session',user:'root'};ids['schedule-editor'].dataset.token='a'.repeat(32);ids['session-login'].href='http://router/cgi-bin/luci/admin/schoolbell';
 const response=(status=200,value={ok:true},type='application/json')=>({status,ok:status>=200&&status<300,headers:new Headers({'Content-Type':type}),json:async()=>value});
 const window={confirm:()=>true,dispatchEvent(e){for(const f of events[e.type]||[])f(e);},fetch:async(u,o={})=>{calls.push({u:String(u),o});if(reply){const f=reply;reply=null;return f(u,o);}return response();}};
 const ctx={window,document:{getElementById:id=>ids[id],addEventListener(t,f){docEvents[t]=f;}},location:{href:'http://router/cgi-bin/luci/admin/schoolbell',assign:u=>calls.push({navigation:u})},URL,Headers,URLSearchParams,AbortController,Set,CustomEvent:class{constructor(t){this.type=t;}},performance:{now:()=>now},Date:{now:()=>now},localStorage:{getItem:k=>stored[k]||null,setItem:(k,v)=>stored[k]=v},setTimeout:()=>1,clearTimeout(){},setInterval:f=>intervals.push(f)};
 vm.runInNewContext(source,ctx);
 return {ids,calls,stored,window,docEvents,response,setReply:f=>reply=f,advance:async(ms)=>{now+=ms;for(const f of intervals)f();for(let i=0;i<8;i++)await Promise.resolve();},on:(k,f)=>(events[k]??=[]).push(f),click:id=>ids[id].events.click()};
}
(async()=>{
 let x=setup(),lost=0;x.on('schoolbell-session-lost',()=>lost++);
 x.setReply(()=>x.response(403));await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/save-schedules',{method:'POST',body:new URLSearchParams({token:'old',draft:'local'})}));assert(lost===1);let count=x.calls.length;
 await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/controls'));assert(x.calls.length===count);
 x.setReply(()=>x.response(200,{ok:true,user:'root',token:'b'.repeat(32)}));await x.click('session-check');assert(x.calls.length===count+1);assert(!x.ids['session-logout'].disabled);
 await x.window.fetch('/cgi-bin/luci/admin/schoolbell/save-schedules',{method:'POST',body:new URLSearchParams({token:'old',draft:'local'})});assert(x.calls.at(-1).o.body.get('token')==='b'.repeat(32));
 await x.window.fetch('/cgi-bin/luci/admin/schoolbell/media',{method:'POST',headers:{Authorization:'Bearer old'},body:'bytes'});assert(x.calls.at(-1).o.headers.get('Authorization')==='Bearer '+'b'.repeat(32));assert(!Object.keys(x.stored).length);
 console.log('PASS expiry gates requests; explicit same-user check updates form/binary CSRF, no replay or token persistence');
 for(const kind of ['redirect','html','401']){x=setup();x.setReply(()=>kind==='redirect'?{type:'opaqueredirect',status:0}:x.response(kind==='401'?401:200,{},'text/html'));await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/clock'));assert(x.ids['session-logout'].disabled);}
 x=setup();x.setReply(()=>{throw Error('network')});await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/clock'));assert(!x.ids['session-logout'].disabled);
 console.log('PASS redirects/login HTML/401 distinguished from network failure');
 x=setup();x.setReply(()=>x.response(403));await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/clock'));
 x.setReply(()=>x.response(200,{ok:true,user:'other',token:'c'.repeat(32)}));await x.click('session-check');assert(x.ids['session-logout'].disabled);
 console.log('PASS different identity cannot resume editor session');
 x=setup();x.window.confirm=()=>false;await x.click('session-logout');assert(!x.calls.length);x.window.confirm=()=>true;x.setReply(()=>x.response(200,{ok:true,logged_out:true}));await x.click('session-logout');assert(x.calls.length===2 && x.calls[0].o.body.get('action')==='logout');assert(x.calls[1].navigation==='http://router/cgi-bin/luci/admin/schoolbell');
 console.log('PASS cancel and explicit logout to normal login without data writes');
 x=setup();x.ids['session-duration'].value='1';x.ids['session-duration'].events.change();await x.advance(30000);await x.window.fetch('/cgi-bin/luci/admin/schoolbell/clock');x.setReply(()=>x.response(200,{ok:true,logged_out:true}));await x.advance(30001);assert(x.calls.length===2 && x.calls[1].o.body.get('action')==='logout');assert(x.stored['schoolbell-idle-minutes']==='1');
 x=setup();await x.advance(600000);x.docEvents.pointerdown({isTrusted:true});await x.advance(600000);assert(!x.calls.length);x.docEvents.input({isTrusted:false});x.setReply(()=>x.response(200,{ok:true,logged_out:true}));await x.advance(1200001);assert(x.calls.length===1);
 console.log('PASS configurable idle countdown; polling/synthetic input do not extend; trusted user activity extends');
 x=setup();let done;x.setReply(()=>new Promise(resolve=>done=resolve));let pending=x.window.fetch('/cgi-bin/luci/admin/schoolbell/schedules');x.setReply(()=>x.response(403));await assert.rejects(x.window.fetch('/cgi-bin/luci/admin/schoolbell/clock'));done(x.response());await assert.rejects(pending);
 x=setup(true);await x.advance(9999999);assert(!x.calls.length && x.ids['session-logout'].disabled && x.ids['session-duration'].disabled);
 console.log('PASS late responses discarded after loss; demo never authenticates or logs out');
})().catch(e=>{console.error(e);process.exit(1)});

// Sound controls must remain disabled even when an old read completes after logout.
(async()=>{
 const ids={},events={},timers=[];let pending,reads=0;
 const get=id=>ids[id]??=( {dataset:{controls:'controls'},options:[],value:'0',textContent:'',disabled:false,addEventListener(){},setAttribute(){},appendChild(o){this.options.push(o);}} );
 const w={addEventListener:(n,f)=>events[n]=f};
 const context={window:w,document:{hidden:false,getElementById:get,addEventListener(){},createElement:()=>({})},fetch:()=>{reads++;return new Promise(resolve=>pending=resolve);},setTimeout:()=>1,clearTimeout(){},setInterval:f=>timers.push(f),AbortController,URLSearchParams,Date,Array,Number,String};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/controls.js','utf8'),context);
 w.schoolbellSessionBlocked=true;events['schoolbell-session-lost']();
 pending({ok:true,json:async()=>({ok:true,muted:false,playing:false})});
 for(let i=0;i<10;i++)await Promise.resolve();
 for(const f of timers)f();
 for(const id of ['quick-mute','quick-bell','router-volume','volume-save'])assert(get(id).disabled,id);
 assert(get('quick-status').textContent.includes('Войдите'));assert.equal(reads,1);
 console.log('PASS logout sound controls stay disabled after late response; polling stops');
})().catch(e=>{console.error(e);process.exitCode=1;});
