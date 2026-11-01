const fs=require('fs'),vm=require('vm'),assert=require('assert');
function setup(){
 let mono=0,wall=1790000000000,calls=[],events={},elements={},reads=[];
 function el(id){return elements[id]||(elements[id]={dataset:{clock:'/clock'},hidden:false,addEventListener(k,f){this[k]=f;}});}
 class Clock extends Date{constructor(...a){super(...(a.length?a:[wall]));}static now(){return wall;}}
 const window={addEventListener:(n,f)=>events[n]=f,dispatchEvent:e=>{if(events[e.type])events[e.type](e);},schoolbellClockCommand:async q=>{calls.push(q);return q.action==='set_prepare'?{ok:true,challenge:'a'.repeat(32),utc:1790000000,zone:'YEKT-5'}:{ok:true};}};
 const context={window,document:{getElementById:el},Date:Clock,Intl,performance:{now:()=>mono},AbortController,Event,setTimeout,clearTimeout,fetch:async()=>{reads.push('clock');return {ok:true,json:async()=>({ok:true,epoch:1790000000,day:21,month:9,year:2026,hour:1,min:2,sec:3})};}};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/time-settings.js','utf8'),context);
 return {el,calls,reads,window,advance:n=>{mono+=n;wall+=n;},step:n=>wall+=n};
}
(async()=>{
 let t=setup();assert.equal(t.reads.length,0);t.el('time-settings').open=true;await t.el('time-settings').toggle();await Promise.resolve();assert.equal(t.reads.length,1);t.el('time-settings').open=false;t.el('time-settings').toggle();assert.equal(t.reads.length,1);
 t=setup();await t.el('time-prepare').click();assert(t.calls.length===1&&!t.el('time-review').hidden);assert(t.el('time-proposal').textContent.includes('UTC'));
 t.el('time-cancel').click();await t.el('time-confirm').click();assert(t.calls.length===1);
 await t.el('time-prepare').click();t.advance(4000);await t.el('time-confirm').click();assert(t.calls.length===3&&t.calls[2].epoch==='1790000004'&&t.calls[2].ack==='true');await t.el('time-confirm').click();assert(t.calls.length===3);
 t=setup();await t.el('time-prepare').click();t.advance(60000);await t.el('time-confirm').click();assert(t.calls.length===1);
 t=setup();await t.el('time-prepare').click();t.step(-3000);await t.el('time-confirm').click();assert(t.calls.length===1);
 t=setup();await t.el('time-prepare').click();t.window.schoolbellSessionBlocked=true;t.window.dispatchEvent(new Event('schoolbell-session-lost'));assert(t.el('time-confirm').disabled);await t.el('time-confirm').click();assert(t.calls.length===1);
 t=setup();await t.el('time-prepare').click();let writes=0;t.window.schoolbellClockCommand=async()=>{writes++;throw Error('response lost');};await t.el('time-confirm').click();await t.el('time-confirm').click();assert(writes===1&&t.el('time-result').textContent.includes('не повторяется'));
 console.log('PASS browser-time UI: prepare/cancel/fresh confirmation/expiry/clock jump/logout/uncertain result without POST replay');
})().catch(e=>{console.error(e);process.exit(1);});
