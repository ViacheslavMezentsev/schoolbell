// Audio status supplement TC-02: actual controls renderer and saved values.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
class E {constructor(){this.attrs={};this.listeners={};this.dataset={controls:'/controls'};this.options=[{value:'-60'},{value:'0'},{value:'-6'}];this.value='-60';}addEventListener(n,f){this.listeners[n]=f;}setAttribute(k,v){this.attrs[k]=v;}removeAttribute(k){delete this.attrs[k];}appendChild(o){this.options.push(o);}}
const els={},get=id=>els[id]||(els[id]=new E());let now=100,interval,reply={ok:true,volume_db:-60,muted:false,playing:false,device:{switch_state:'ready',position:'AP',ip:'192.0.2.1'},audio:{state:'ready',name:'C-Media',model:'USB PnP Sound Device',controller:'OHCI'}},fail=false;
const posts=[];const events={};const win={addEventListener(n,f){events[n]=f;}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/controls.js','utf8'),{window:win,document:{getElementById:get,addEventListener(){},hidden:false,createElement(){return new E();}},Date:{now:()=>now},fetch:async(url,options)=>{if(options && options.body)posts.push(options.body.get('volume_db'));if(fail)throw Error('network');return {ok:true,json:async()=>reply};},AbortController,URLSearchParams,setTimeout:()=>1,clearTimeout(){},setInterval:f=>{interval=f;}});
const flush=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{await flush();assert.equal(get('audio-route').textContent,'OHCI · C-Media (USB PnP Sound Device)');assert.equal(get('audio-volume').textContent,'0 %');
assert.equal(get('device-switch').textContent,'Переключатель: AP');assert.equal(get('device-ip').textContent,'IP: 192.0.2.1');assert.equal(posts.length,0);assert.equal(get('router-volume').value,'0');assert.equal(get('media-output-summary').textContent,'Аудио: OHCI · C-Media (USB PnP Sound Device) 0 %');
reply={...reply,volume_db:-17};now+=16000;interval();await flush();assert.equal(get('router-volume').value,'1');assert.equal(get('audio-volume').textContent,'14 %');assert.equal(get('volume-line').attrs['aria-valuenow'],'14');assert.equal(get('volume-line').attrs.style,'--volume-fill:14%');assert.equal(posts.length,0);
get('router-volume').value='10';get('router-volume').listeners.input();assert.equal(get('volume-value').textContent,'100 %');assert.equal(posts.length,0);assert.equal(get('audio-volume').textContent,'14 %');assert.equal(get('volume-line').attrs['aria-valuenow'],'14');assert.equal(get('volume-line').attrs.style,'--volume-fill:14%');
for(let i=0;i<=10;i++){get('router-volume').value=String(i);get('router-volume').listeners.input();assert.equal(get('volume-value').textContent,(i*10)+' %');assert.equal(posts.length,0);} reply={...reply,volume_db:0};await get('volume-save').listeners.click();assert.equal(get('audio-volume').textContent,'100 %');assert.deepEqual(posts,['0']);assert(get('volume-status').textContent.includes('100%'));
reply={...reply,volume_db:-6,muted:true,audio:{state:'missing'}};now+=16000;interval();await flush();assert.equal(get('audio-route').textContent,'не обнаружено');assert.equal(get('audio-volume').textContent,'50 %');assert.equal(get('volume-line').attrs['aria-valuenow'],'50');
// Every UI step survives save/readback without drift; movement never sends a command.
for(const [i,db] of [-60,-20,-14,-10,-8,-6,-4,-3,-2,-1,0].entries()){
 const before=posts.length;get('router-volume').value=String(i);get('router-volume').listeners.input();assert.equal(posts.length,before);assert.equal(get('volume-value').textContent,(i*10)+' %');
 reply={...reply,volume_db:db};await get('volume-save').listeners.click();assert.equal(posts.at(-1),String(db));assert.equal(get('audio-volume').textContent,(i*10)+' %');assert.equal(get('router-volume').value,String(i));
}
get('router-volume').value='99';get('router-volume').listeners.input();const invalidPosts=posts.length;await get('volume-save').listeners.click();assert.equal(posts.length,invalidPosts);get('router-volume').value='10';get('router-volume').listeners.input();
reply={...reply,audio:{state:'ready',name:'<img onerror=bad>',controller:'EHCI'}};now+=16000;interval();await flush();assert(get('audio-route').textContent.includes('<img onerror=bad>'));
fail=true;now+=16000;interval();
assert(get('audio-route').textContent.includes('EHCI'),'keep the reading during normal poll latency');
await flush();assert(get('audio-route').textContent.includes('EHCI'));assert(get('resource-audio-age').textContent.includes('последние данные'));assert(get('quick-bell').disabled);
now+=45000;interval();await flush();assert.equal(get('audio-route').textContent,'нет данных');assert.equal(get('audio-volume').textContent,'— %');assert.equal(get('volume-line').attrs['aria-valuenow'],undefined);assert.equal(get('volume-line').attrs['data-tone'],'unknown');assert.equal(get('device-switch').textContent,'Переключатель: не определён');assert.equal(get('device-ip').textContent,'IP: —');
fail=false;reply={ok:true,volume_db:-60,hardware:false,audio:{state:'demo'}};now+=16000;interval();await flush();assert(get('audio-route').textContent.includes('демо'));assert.equal(get('device-switch').textContent,'Переключатель: демо');
reply={...reply,confirm_play:true};now+=16000;interval();await flush();
let prompts=0,sends=0;win.confirm=()=>{prompts++;return false;};
assert.equal(await win.schoolbellSpeakerCommand(()=>{sends++;}),null);assert.equal(prompts,1);assert.equal(sends,0);
win.confirm=()=>true;await win.schoolbellSpeakerCommand(ok=>{assert.equal(ok,true);sends++;return {state:'completed'};});assert.equal(sends,1);
reply={...reply,confirm_play:false};now+=16000;interval();await flush();
const sent=[];await win.schoolbellSpeakerCommand(ok=>{sent.push(ok);return {state:ok?'completed':'confirmation_required'};});assert.deepEqual(sent,[false,true]);
win.schoolbellSessionBlocked=true;events['schoolbell-session-lost']();assert.equal(get('audio-route').textContent,'нет данных');
const css=fs.readFileSync('ui/root/www/schoolbell-test/style.css','utf8');assert.match(css,/#flash-line i\{[^}]*background:var\(--accent\)/);assert.match(css,/#flash-line\[data-tone=warning\] i\{background:#bf8700/);assert.match(css,/#flash-line\[data-tone=danger\] i\{background:#da3633/);
console.log('PASS audio UI: saved dB/gain, default node, absence, network/logout/demo, safe text, Flash colors');})().catch(e=>{console.error(e);process.exitCode=1;});
