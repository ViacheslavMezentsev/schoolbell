const fs=require('fs'),vm=require('vm'),assert=require('assert');
const elements=new Map(),events=[],timers=[];
function el(id){if(!elements.has(id))elements.set(id,{value:'',handlers:{},addEventListener(k,fn){this.handlers[k]=fn;}});return elements.get(id);}
let value={ok:true,zone:'UTC',enabled:false,sim:{epoch:1794205800,speed:1,audio:'ready',internet:'available',ntp:'synced',seen:{}},next:null};
const context={document:{hidden:false,activeElement:null,getElementById:el},window:{dispatchEvent(e){events.push(e.type);}},CustomEvent:class{constructor(type){this.type=type;}},fetch:async()=>({json:async()=>JSON.parse(JSON.stringify(value))}),setInterval:fn=>timers.push(fn),URLSearchParams,Intl,Date,JSON,Object,String,confirm:()=>false};
const flush=async()=>{for(let i=0;i<8;i++)await Promise.resolve();};
(async()=>{vm.runInNewContext(fs.readFileSync('site/simulator-ui.js','utf8'),context);await flush();events.length=0;
for(let i=0;i<4;i++){value.sim.epoch++;await timers[0]();}assert.deepEqual(events,[],'ordinary ticking must not invalidate shared status');
const input=el('simulator-time');input.value='2026-11-15T09:00';input.handlers.input();value.sim.epoch++;await timers[0]();assert.equal(input.value,'2026-11-15T09:00','preserve unsaved input');
await el('simulator-set-time').handlers.click();assert(events.includes('schoolbell-time-changed'));assert.notEqual(input.value,'2026-11-15T09:00');
events.length=0;value.sim.epoch+=3600;await timers[0]();assert(!events.includes('schoolbell-time-changed'));assert.equal(input.value,new Date(value.sim.epoch*1000).toISOString().slice(0,19),'external clock changes update untouched input');
value.sim.seen.one=true;await timers[0]();assert(events.includes('schoolbell-simulator-update'));assert(!events.includes('schoolbell-time-changed'));
console.log('PASS simulator UI: ticking does not invalidate status, events refresh once, edited time retained and synchronized values rendered');
})().catch(e=>{console.error(e);process.exitCode=1;});
