const fs=require('fs'),vm=require('vm'),assert=require('assert');
function setup(){
 let mono=0,wall=1790000000000,calls=[],events={},elements={},reads=[];
 function el(id){return elements[id]||(elements[id]={dataset:{clock:'/clock'},hidden:false,children:[],appendChild(n){this.children.push(n);},addEventListener(k,f){this[k]=f;}});}
 class Clock extends Date{constructor(...a){super(...(a.length?a:[wall]));}static now(){return wall;}}
 const window={addEventListener:(n,f)=>events[n]=f,dispatchEvent:e=>{if(events[e.type])events[e.type](e);},schoolbellClockCommand:async q=>{calls.push(q);return q.action==='set_prepare'?{ok:true,challenge:'a'.repeat(32),utc:1790000000,zone:'YEKT-5'}:{ok:true};}};
 const context={window,document:{getElementById:el,createElement:()=>({})},Date:Clock,Intl,performance:{now:()=>mono},AbortController,Event,setTimeout,clearTimeout,fetch:async()=>{reads.push('clock');return {ok:true,json:async()=>({ok:true,epoch:1790000000,day:21,month:9,year:2026,hour:1,min:2,sec:3})};}};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/time-settings.js','utf8'),context);
 return {el,calls,reads,window,advance:n=>{mono+=n;wall+=n;},step:n=>wall+=n};
}
(async()=>{
 for(const [shift,expected] of [[900,'совпадают'],[1900,'отстают на 1 с'],[-100,'спешат на 1 с']]){const c=setup();c.step(shift);await c.el('time-reload').click();assert(c.el('time-difference').textContent.includes(expected),c.el('time-difference').textContent);}
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
const source=fs.readFileSync('ui/root/www/schoolbell-test/time-settings.js','utf8');
const nodes={};
const clockContext={Intl,Date,document:{createElement:()=>({}),getElementById:id=>nodes[id]||(nodes[id]={children:[],set textContent(v){this.children=[];},appendChild(v){this.children.push(v);}})}};
vm.createContext(clockContext);
vm.runInContext(source.slice(source.indexOf('function clockParts'),source.indexOf('async function read')),clockContext);
const parts=clockContext.clockParts(new Date('2026-11-08T00:04:12Z'),'UTC');
clockContext.paintTime('equal',parts,parts,'UTC','UTC');
assert.equal(nodes.equal.children.filter(n=>n.className).length,0);
for(const type of ['day','month','year','hour','minute','second']){
 const changed=parts.map(p=>({type:p.type,value:p.type===type?'99':p.value}));
 clockContext.paintTime(type,parts,changed,'UTC','UTC');
 assert.equal(nodes[type].children.filter(n=>n.className).length,1);
}
clockContext.paintTime('zone',parts,parts,'UTC','Asia/Yekaterinburg');
assert.equal(nodes.zone.children.filter(n=>n.className).length,1);
assert(nodes.equal.children.map(n=>n.textContent).join('').startsWith('08.11.2026'));
console.log('PASS clocks: identical formatting and separate highlighting of date, time and zone');
