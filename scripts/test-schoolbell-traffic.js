/* Schoolbell TC-160: passive request accounting with controlled monotonic clock. */
'use strict';
const assert=require('node:assert/strict');
const {create,observe}=require('../ui/root/www/schoolbell-test/traffic.js');
(async()=>{
 let now=0,m=create(()=>now);assert.equal(m.snapshot().items.length,12);
 const a=m.begin('GET');now=4999;const b=m.begin('POST');m.end(a,false);
 assert.equal(m.snapshot().items[11].reads,1);assert.equal(m.snapshot().items[11].commands,1);
 now=5000;m.end(b,true);assert.equal(m.snapshot().items[10].errors,1);
 assert.equal(m.snapshot().pending,0);m.end(b,true);assert.equal(m.snapshot().pending,0);
 now=60000;assert.equal(m.snapshot().items.reduce((n,x)=>n+x.reads+x.commands,0),0);
 const late=m.begin('HEAD');now=600000;m.end(late,false);
 assert.equal(m.snapshot().pending,0);assert.equal(m.snapshot().items.reduce((n,x)=>n+x.finished,0),0);
 for(let i=0;i<1000;i++){now+=5000;const t=m.begin('GET');m.end(t,false);assert.equal(m.snapshot().items.length,12);}
 now=0;m=create(()=>now);let calls=0;const reply={ok:true,json:()=>({ok:false,code:'busy'})};
 const options={method:'POST',signal:{},body:'secret'};
 const f=observe((input,opts)=>{calls++;assert.equal(input,'api');assert.equal(opts,options);now=125;return Promise.resolve(reply);},m,u=>u==='api');
 assert.equal(await f('api',options),reply);assert.equal(calls,1);assert.equal(m.snapshot().items[11].max,125);assert.equal(m.snapshot().items[11].errors,0);
 const error=new Error('aborted');const fail=observe(()=>Promise.reject(error),m,()=>true);
 await assert.rejects(fail('api'),e=>e===error);assert.equal(m.snapshot().pending,0);assert.equal(m.snapshot().items[11].errors,1);
 const sync=observe(()=>{throw error;},m,()=>true);assert.throws(()=>sync('api'),e=>e===error);assert.equal(m.snapshot().pending,0);
 const http=observe(()=>Promise.resolve({ok:false,status:403}),m,()=>true);await http('api');assert.equal(m.snapshot().items[11].errors,3);
 const before=JSON.stringify(m.snapshot());const passthrough=observe(()=>reply,m,()=>false);assert.equal(passthrough('audio'),reply);assert.equal(JSON.stringify(m.snapshot()),before);
 let resolve;const pending=observe(()=>new Promise(r=>resolve=r),m,()=>true);const p=pending('api');assert.equal(m.snapshot().pending,1);resolve(reply);await p;assert.equal(m.snapshot().pending,0);
 // Per-method counts retain the same start-window semantics as the chart.
 now=0;m=create(()=>now);
 const read=m.begin('GET','automatic'),command=m.begin('POST','test');now=7259;m.end(command,false);now=7300;m.end(read,false);
 let groups=m.snapshot().methods;assert.equal(groups.length,2);
 assert.equal(groups.find(x=>x.id==='POST test').max,7259);assert.equal(groups.find(x=>x.id==='GET automatic').max,7300);
 const rejected=m.begin('POST','test');now+=100;m.end(rejected,true);m.end(rejected,true);
 groups=m.snapshot().methods;const test=groups.find(x=>x.id==='POST test');assert.equal(test.finished,2);assert.equal(test.total,7359);assert.equal(test.errors,1);assert.equal(test.pending,0);
 const hanging=m.begin('GET','backup');now+=60000;
 groups=m.snapshot().methods;assert.equal(groups.length,1);assert.equal(groups[0].id,'GET backup');assert.equal(groups[0].pending,1);assert.equal(groups[0].finished,0);
 m.end(hanging,false);assert.equal(m.snapshot().methods.length,0);
 for(let i=0;i<200;i++){const ticket=m.begin('UNTRUSTED'+i,'/secret?token='+i);m.end(ticket,false);}
 assert.equal(m.snapshot().methods.length,1);assert.equal(m.snapshot().methods[0].id,'OTHER other');assert.ok(!JSON.stringify(m.snapshot()).includes('secret'));
 const immutable=m.snapshot().methods;immutable[0].total=-1;assert.notEqual(m.snapshot().methods[0].total,-1);
 now=0;m=create(()=>now);
 // Browser integration: all sections are observed even while Journal is hidden.
 const vm=require('node:vm');const fs=require('node:fs');let sent=0,tick;
 const elements={
  'traffic-methods':{},'traffic-method-rows':{rows:[],replaceChildren(){this.rows=[];},appendChild(row){this.rows.push(row);}},'traffic-kind':{value:'http',addEventListener(n,f){this.change=f;}},'traffic-kind-label':{},'traffic-http-info':{},'traffic-http-note':{},'queue-explanation':{},'queue-legend':{},'traffic-chart':{replaceChildren(){},appendChild(){},listeners:{},addEventListener(n,f){this.listeners[n]=f;},getBoundingClientRect(){return {left:0,width:700};}},'traffic-hint':{},
  'schedule-editor':{dataset:{load:'/api/load',save:'/api/save',sample:'/api/audio',token:'secret'}},
  'session-panel':{dataset:{session:'/api/session'}},
  'backup-panel':{dataset:{url:'/api/backup'}},
  'router-form':{action:'http://device/api/play'},
  'panel-journal':{hidden:true},'traffic-mode':{},'traffic-scale':{},'traffic-stats':{}
 };
 const listeners={};const window={addEventListener(n,f){listeners[n]=f;},fetch:async()=>{sent++;return reply;}};
 const document={hidden:false,getElementById:id=>elements[id],createElement:()=>({children:[],appendChild(x){this.children.push(x);}}),createElementNS:()=>({setAttribute(){},appendChild(){}})};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/traffic.js','utf8'),{window,document,URL,Set,performance:{now:()=>now},location:{href:'http://device/page',origin:'http://device'},setInterval:f=>{tick=f;}});
 assert.equal(sent,0);
 await window.fetch('/api/load');await window.fetch('/api/save',{method:'POST'});
 await window.fetch('/api/backup?action=status');await window.fetch('/api/audio');await window.fetch('http://other/api/load');
 elements['panel-journal'].hidden=false;tick();
 assert.match(elements['traffic-stats'].textContent,/Чтение: 2 · Команды: 1/);
 assert.equal(sent,5);tick();assert.equal(sent,5);
 assert.equal(elements['traffic-method-rows'].rows.length,3);assert.match(elements['traffic-method-rows'].rows.map(r=>r.children[0].textContent).join(','),/GET schedules/);
 assert.equal(elements['traffic-methods'].hidden,false);
 const graph=elements['traffic-chart'];graph.listeners.pointermove({clientX:680});
 assert.match(elements['traffic-hint'].textContent,/всего 3 · чтение 2 · команды 1/);
 tick();assert.match(elements['traffic-hint'].textContent,/всего 3/);
 graph.listeners.keydown({key:'Home',preventDefault(){}});assert.match(elements['traffic-hint'].textContent,/всего 0/);
 graph.listeners.click({clientX:680});assert.match(elements['traffic-hint'].textContent,/всего 3/);
 now+=60000;tick();assert.match(elements['traffic-hint'].textContent,/Наведите/);
 assert.equal(sent,5);

 elements['traffic-kind'].value='queue';elements['traffic-kind'].change();assert.equal(elements['traffic-methods'].hidden,true);assert.match(elements['traffic-hint'].textContent,/Нет свежих/);
 listeners['schoolbell-queue-metrics']({detail:{available:true,now:100,depth:0,running:1,bins:[{key:20,depth:1,processed:2,failed:1,wait_count:2,wait_sum:1000,wait_max:700}]}});
 assert.match(elements['traffic-stats'].textContent,/Обработано: 2/);assert.match(elements['traffic-stats'].textContent,/500 \/ 700 мс/);
 now+=16000;tick();assert.match(elements['traffic-hint'].textContent,/Нет свежих/);assert.equal(sent,5);
const html=fs.readFileSync('ui/root/usr/lib/lua/luci/view/schoolbell_test.htm','utf8');
 assert.ok(html.indexOf('/schoolbell-test/traffic.js')<html.indexOf('/schoolbell-test/session.js'));
 assert.ok(html.includes('id="traffic-chart"'));assert.ok(html.includes('не внутренние обмены исполнителя'));
 console.log('PASS traffic: 5s boundaries, 12-slot retention, late/duplicate completions, latency, HTTP/rejection/abort, pass-through, no retries, device script order (Pages build order deferred to M3)');
})().catch(e=>{console.error(e);process.exit(1);});
