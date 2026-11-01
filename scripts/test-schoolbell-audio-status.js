// Audio status supplement TC-02: actual controls renderer and saved values.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
class E {constructor(){this.listeners={};this.dataset={controls:'/controls'};this.options=[{value:'-60'},{value:'0'},{value:'-6'}];this.value='-60';}addEventListener(n,f){this.listeners[n]=f;}setAttribute(){}appendChild(o){this.options.push(o);}}
const els={},get=id=>els[id]||(els[id]=new E());let now=100,interval,reply={ok:true,volume_db:-60,muted:false,playing:false,audio:{state:'ready',name:'C-Media',model:'USB PnP Sound Device',controller:'OHCI'}},fail=false;
const posts=[];const events={};const win={addEventListener(n,f){events[n]=f;}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/controls.js','utf8'),{window:win,document:{getElementById:get,addEventListener(){},hidden:false,createElement(){return new E();}},Date:{now:()=>now},fetch:async(url,options)=>{if(options && options.body)posts.push(options.body.get('volume_db'));if(fail)throw Error('network');return {ok:true,json:async()=>reply};},AbortController,URLSearchParams,setTimeout:()=>1,clearTimeout(){},setInterval:f=>{interval=f;}});
const flush=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{await flush();assert.equal(get('audio-route').textContent,'Аудио: OHCI · C-Media (USB PnP Sound Device)');assert.equal(get('audio-volume').textContent,'0%');
assert.equal(posts.length,0);assert.equal(get('router-volume').value,'-60');assert.equal(get('media-output-summary').textContent,'Аудио: OHCI · C-Media (USB PnP Sound Device) 0%');
reply={...reply,volume_db:-17};now+=16000;interval();await flush();assert.equal(get('router-volume').value,'-17');assert.equal(get('audio-volume').textContent,'14%');assert.equal(posts.length,0);
get('router-volume').value='0';get('router-volume').listeners.change();assert.equal(get('audio-volume').textContent,'14%');
reply={...reply,volume_db:0};await get('volume-save').listeners.click();assert.equal(get('audio-volume').textContent,'100%');assert.deepEqual(posts,['0']);assert(get('volume-status').textContent.includes('100%'));
reply={...reply,volume_db:-6,audio:{state:'missing'}};now+=16000;interval();await flush();assert.equal(get('audio-route').textContent,'Аудио: не обнаружено');assert.equal(get('audio-volume').textContent,'50%');
reply={...reply,audio:{state:'ready',name:'<img onerror=bad>',controller:'EHCI'}};now+=16000;interval();await flush();assert(get('audio-route').textContent.includes('<img onerror=bad>'));
fail=true;now+=16000;interval();await flush();assert.equal(get('audio-route').textContent,'Аудио: нет данных');assert.equal(get('audio-volume').textContent,'—%');
fail=false;reply={ok:true,volume_db:-60,hardware:false,audio:{state:'demo'}};now+=16000;interval();await flush();assert(get('audio-route').textContent.includes('демо'));
win.schoolbellSessionBlocked=true;events['schoolbell-session-lost']();assert.equal(get('audio-route').textContent,'Аудио: нет данных');
const css=fs.readFileSync('ui/root/www/schoolbell-test/style.css','utf8');assert.match(css,/#flash-line i\{[^}]*background:var\(--accent\)/);assert.match(css,/#flash-line\[data-tone=warning\] i\{background:#bf8700/);assert.match(css,/#flash-line\[data-tone=danger\] i\{background:#da3633/);
console.log('PASS audio UI: saved dB/gain, default node, absence, network/logout/demo, safe text, Flash colors');})().catch(e=>{console.error(e);process.exitCode=1;});
