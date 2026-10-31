const fs=require('fs'),vm=require('vm'),assert=require('assert');
const elements=new Map(),storage=new Map();
const document={getElementById(id){if(!elements.has(id))elements.set(id,{addEventListener(){},textContent:''});return elements.get(id);}};
let demoNow=0;
const context={performance:{now:()=>demoNow},window:{},document,TextEncoder,Intl,Date,Math,Number,JSON,Array,String,URL,URLSearchParams,Response:class{constructor(body){this.body=body;this.ok=true;}json(){return Promise.resolve(JSON.parse(this.body));}},location:{href:'https://example.test/openwrt-modbus-core/schoolbell/',origin:'https://example.test'},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/ranges.js','utf8'),context);
vm.runInNewContext(fs.readFileSync(require('path').join(__dirname,'../site/demo.js'),'utf8'),context);
async function api(name,data){return (await context.window.fetch('./demo-api/'+name,data?{method:'POST',body:new URLSearchParams(data)}:undefined)).json();}
(async()=>{
 let q=(await api('automatic')).queue;assert(q.available&&q.simulated&&q.bins.length===0);
 await api('clock-trust',{action:'prepare'});q=(await api('automatic')).queue;assert(q.bins[0].processed===1&&q.bins[0].wait_sum===0);
 demoNow=61000;assert((await api('automatic')).queue.bins.length===0);
 let first=await api('load');assert(first.ok && first.data.schedules.length===3);
 first.data.schedules[0].name='Changed';first.data.schedules[0].color=16;
 let saved=await api('save',{revision:first.revision,draft:JSON.stringify(first.data)});assert(saved.ok);
 assert((await api('load')).data.schedules[0].color===16);
 assert((await api('save',{revision:first.revision,draft:JSON.stringify(first.data)})).code==='conflict');
 const draft={pre_minutes:5,pre_media:'test',schedules:[{id:'s',name:'Test',color:1,rows:[{id:'r',time:'00:03',media:'test',enabled:true,pre:true}]}],plans:[{year:2026,schedule_ids:['s'],days:'.AA'+'.'.repeat(362)}]};
 assert((await api('preview',{date:'2026-01-01',draft:JSON.stringify(draft)})).events.length===0);
 let events=(await api('preview',{date:'2026-01-02',draft:JSON.stringify(draft)})).events;
 assert(events.length===2 && events[1].time==='23:58' && events[1].origin_date==='2026-01-03');
 let tz=await api('timezone');assert((await api('timezone',{zone:'UTC',revision:tz.revision})).ok);assert((await api('clock')).ok);
 for(let i=0;i<500;i++){let value=await api('load');assert((await api('save',{revision:value.revision,draft:JSON.stringify(value.data)})).ok);}
 const journal=await api('journal');assert(journal.limit_bytes===32768 && journal.entries.length>80 && journal.entries.length<500);const persisted=JSON.parse([...storage.values()][0]);assert(new TextEncoder().encode(JSON.stringify(persisted.log)).length<=32768);
 await assert.rejects(()=>context.window.fetch('http://192.0.2.1/api'));await assert.rejects(()=>context.window.fetch('/cgi-bin/luci'));
 assert((await api('no-router',{})).state==='unavailable');
 assert((await api('automatic')).hardware===false);
 const appliedDraft=await api('load');await api('clock-trust',{action:'confirm'});
 assert((await api('clock-trust',{action:'enable',revision:appliedDraft.revision})).ok);
 let auto=await api('automatic');assert(auto.enabled && auto.simulated && auto.hardware===false);
 await api('automatic',{enabled:'false'});auto=await api('automatic');assert(!auto.enabled && auto.revision===appliedDraft.revision);
 const changedDraft=JSON.parse(JSON.stringify(appliedDraft.data));changedDraft.schedules[0].name='Newer draft';
 assert((await api('save',{revision:appliedDraft.revision,draft:JSON.stringify(changedDraft)})).ok);
 assert((await api('clock-trust',{action:'resume',revision:auto.revision,generation:String(auto.generation)})).ok);
 assert((await api('automatic')).revision===appliedDraft.revision);
 assert((await api('clock-trust',{action:'resume',revision:auto.revision,generation:String(auto.generation)})).code==='active_conflict');
 await api('automatic',{enabled:'false'});

 let prep=await api('clock-trust',{action:'set_prepare',operation:'a'.repeat(32)});assert(prep.simulated && prep.ttl===60);
 const timeData={action:'set_time',challenge:prep.challenge,epoch:String(Math.floor(Date.now()/1000)),ack:'true'};
 assert((await api('clock-trust',timeData)).simulated);assert(!(await api('automatic')).enabled);
 assert((await api('automatic')).clock_trust.state==='unconfirmed');
 assert((await api('clock-trust',timeData)).code==='stale_confirmation');
 prep=await api('clock-trust',{action:'set_prepare',operation:'b'.repeat(32)});demoNow+=60000;assert((await api('clock-trust',{...timeData,challenge:prep.challenge})).code==='stale_confirmation');
 let volume=await api('controls',{volume_db:'-12'});assert(volume.volume_db===-12);
 assert((await api('controls')).volume_db===-12);
 assert((await api('automatic',{enabled:'true'})).enabled===false);
 let challenge=await api('clock-trust',{action:'prepare'});assert(challenge.challenge==='demo');
 await api('clock-trust',{action:'confirm'});assert((await api('automatic')).clock_trust.state==='confirmed');
 await api('clock-trust',{action:'policy',enforced:'false'});assert((await api('automatic')).clock_trust.enforced===false);assert((await api('automatic')).enabled===false);

 const rangeRaw=fs.readFileSync('tests/range-plan.json','utf8');const rangeDates=['2026-12-29','2026-12-30','2026-12-31','2027-01-01','2027-01-02','2027-01-03','2027-01-04'];
 const results=[];for(const date of rangeDates)results.push(await api('preview',{date,draft:rangeRaw}));
 assert.equal(results[1].events.length,0);assert.equal(results[2].events.length,3);assert.equal(results[2].events[2].origin_date,'2027-01-01');assert.equal(results[4].events.length,0);
 if(process.env.SCHOOLBELL_LUA){const cp=require('child_process');const lua=cp.execFileSync(process.env.SCHOOLBELL_LUA,['tests/range-preview.lua','tests/range-plan.json',...rangeDates],{encoding:'utf8'}).trim().split('\n').map(JSON.parse);for(let i=0;i<results.length;i++)assert.deepStrictEqual(results[i],lua[i]);console.log('PASS exact Pages/Lua preview parity for range edges, gaps and cross-midnight pre-bell');}
 const bad=JSON.parse(rangeRaw);bad.plans[1].start='2026-12-31';assert.equal((await api('preview',{date:'2027-01-01',draft:JSON.stringify(bad)})).code,'invalid');
 bad.plans=JSON.parse(rangeRaw).plans;bad.schedules[0].rows[0].media='user1';assert.equal((await api('preview',{date:'2027-01-01',draft:JSON.stringify(bad)})).code,'invalid');
 console.log('PASS demo: local persistence, CAS, midnight/quiet-day preview, mock zone, bounded journal, blocked remote API');
})().catch(e=>{console.error(e);process.exitCode=1;});
