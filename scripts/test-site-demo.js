const fs=require('fs'),vm=require('vm'),assert=require('assert');
const elements=new Map(),storage=new Map();
const document={getElementById(id){if(!elements.has(id))elements.set(id,{addEventListener(){},textContent:''});return elements.get(id);}};
let demoNow=0;
const context={performance:{now:()=>demoNow},window:{},document,TextEncoder,Intl,Date,Math,Number,JSON,Array,String,URL,URLSearchParams,Response:class{constructor(body){this.body=body;this.ok=true;}json(){return Promise.resolve(JSON.parse(this.body));}},location:{href:'https://example.test/openwrt-modbus-core/schoolbell/',origin:'https://example.test'},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/ranges.js','utf8'),context);
vm.runInNewContext(fs.readFileSync(require('path').join(__dirname,'../site/demo.js'),'utf8'),context);
async function api(name,data){return (await context.window.fetch('./demo-api/'+name,data?{method:'POST',body:new URLSearchParams(data)}:undefined)).json();}
(async()=>{
 assert(!('queue' in (await api('automatic'))));
 let first=await api('load');assert(first.ok && first.data.schedules.length===3);
 first.data.schedules[0].name='Changed';first.data.schedules[0].color=16;
 let saved=await api('save',{revision:first.revision,draft:JSON.stringify(first.data)});assert(saved.ok);
 assert((await api('load')).data.schedules[0].color===16);
 assert((await api('save',{revision:first.revision,draft:JSON.stringify(first.data)})).code==='conflict');
 const draft={active_plan:'year-2026',pre_minutes:5,pre_media:'test',schedules:[{id:'s',name:'Test',color:1,rows:[{id:'r',time:'00:03',media:'test',enabled:true,pre:true}]}],plans:[{year:2026,schedule_ids:['s'],days:'.AA'+'.'.repeat(362)}]};
 assert((await api('preview',{date:'2026-01-01',draft:JSON.stringify(draft)})).events.length===0);
 const input={date:'2026-01-02',draft:JSON.stringify(draft)};
 const firstPreview=await api('preview',input),repeatPreview=await api('preview',input);
 assert.deepEqual(repeatPreview,firstPreview);
 const edited=JSON.parse(input.draft);edited.plans[0].days='.'.repeat(365);
 assert.equal((await api('preview',{...input,draft:JSON.stringify(edited)})).events.length,0);
 let events=(await api('preview',{date:'2026-01-02',draft:JSON.stringify(draft)})).events;
 assert(events.length===2 && events[1].time==='23:58' && events[1].origin_date==='2026-01-03');
 let tz=await api('timezone');assert((await api('timezone',{zone:'UTC',revision:tz.revision})).ok);assert((await api('clock')).ok);
 for(let i=0;i<500;i++){let value=await api('load');assert((await api('save',{revision:value.revision,draft:JSON.stringify(value.data)})).ok);}
 const journal=await api('journal');assert(journal.limit_bytes===32768 && journal.entries.length>80 && journal.entries.length<500);const persisted=JSON.parse([...storage.values()][0]);assert(journal.retention_seconds===undefined);const logKey=[...storage.keys()][0];persisted.log[0].time=0;storage.set(logKey,JSON.stringify(persisted));const oldSeq=persisted.log[0].seq;assert((await api('journal')).entries.some(e=>e.seq===oldSeq && e.time===0));assert(new TextEncoder().encode(JSON.stringify(persisted.log)).length<=32768);
 await assert.rejects(()=>context.window.fetch('http://192.0.2.1/api'));await assert.rejects(()=>context.window.fetch('/cgi-bin/luci'));
 assert((await api('no-router',{})).state==='unavailable');
 assert((await api('automatic')).hardware===false);
 const appliedDraft=await api('load');assert((await api('automatic',{action:'apply',revision:appliedDraft.revision})).enabled===false);
 assert((await api('clock-trust',{action:'resume',revision:appliedDraft.revision,generation:String((await api('automatic')).generation)})).ok);
 let auto=await api('automatic');assert(auto.enabled && auto.simulated && auto.hardware===false);
 await api('automatic',{enabled:'false'});auto=await api('automatic');assert(!auto.enabled && auto.revision===appliedDraft.revision);
 const changedDraft=JSON.parse(JSON.stringify(appliedDraft.data));changedDraft.schedules[0].name='Newer draft';
 assert((await api('save',{revision:appliedDraft.revision,draft:JSON.stringify(changedDraft)})).ok);
 assert((await api('clock-trust',{action:'resume',revision:auto.revision,generation:String(auto.generation)})).ok);
 assert((await api('automatic')).revision===appliedDraft.revision);
 assert((await api('clock-trust',{action:'resume',revision:auto.revision,generation:String(auto.generation)})).code==='active_conflict');
 await api('automatic',{enabled:'false'});

 // A fixed schedule is editable after stop, but the retained snapshot still protects deletion.
 const beforeFixed=await api('load'),fixed=JSON.parse(JSON.stringify(beforeFixed.data));
 fixed.mode='fixed';fixed.fixed_schedule=fixed.schedules[0].id;
 const fixedSave=await api('save',{revision:beforeFixed.revision,draft:JSON.stringify(fixed)});assert(fixedSave.ok);
 const staged=await api('automatic',{action:'apply',revision:fixedSave.revision});assert(staged.ok && !staged.enabled);
 assert((await api('clock-trust',{action:'resume',revision:fixedSave.revision,generation:String(staged.generation)})).ok);
 fixed.schedules[0].name='Edited fixed';
 assert.equal((await api('save',{revision:fixedSave.revision,draft:JSON.stringify(fixed)})).code,'source_running');
 assert((await api('automatic',{action:'apply',revision:fixedSave.revision})).enabled);
 await api('automatic',{enabled:'false'});
 assert((await api('save',{revision:fixedSave.revision,draft:JSON.stringify(fixed)})).ok);
 let prep=await api('clock-trust',{action:'set_prepare',operation:'a'.repeat(32)});assert(prep.simulated && prep.ttl===60);
 const timeData={action:'set_time',challenge:prep.challenge,epoch:String(Math.floor(Date.now()/1000)),ack:'true'};
 assert((await api('clock-trust',timeData)).simulated);assert(!(await api('automatic')).enabled);

 assert((await api('clock-trust',timeData)).code==='stale_confirmation');
 prep=await api('clock-trust',{action:'set_prepare',operation:'b'.repeat(32)});demoNow+=60000;assert((await api('clock-trust',{...timeData,challenge:prep.challenge})).code==='stale_confirmation');
 let volume=await api('controls',{volume_db:'-12'});assert(volume.volume_db===-12);
 assert((await api('controls')).volume_db===-12);
 assert((await api('automatic',{enabled:'true'})).enabled===false);
 assert(!(await api('clock-trust',{action:'policy',enforced:'false'})).ok);
 const stopped=await api('automatic');assert((await api('clock-trust',{action:'resume',revision:stopped.revision,generation:String(stopped.generation)})).ok);
 assert((await api('automatic')).enabled);
 await api('demo-boot',{});assert(!(await api('automatic')).enabled);
 assert((await api('journal')).entries.filter(e=>e.action==='device_boot').length===1);

 const rangeRaw=fs.readFileSync('tests/range-plan.json','utf8');const rangeDates=['2026-12-29','2026-12-30','2026-12-31','2027-01-01','2027-01-02','2027-01-03','2027-01-04'];
 const results=[];for(const date of rangeDates)results.push(await api('preview',{date,draft:rangeRaw}));
 assert.equal(results[1].events.length,0);assert.equal(results[2].events.length,2);assert.equal(results[3].events.length,0);assert.equal(results[4].events.length,0);
 if(process.env.SCHOOLBELL_LUA){const cp=require('child_process');const lua=cp.execFileSync(process.env.SCHOOLBELL_LUA,['tests/range-preview.lua','tests/range-plan.json',...rangeDates],{encoding:'utf8'}).trim().split('\n').map(JSON.parse);for(let i=0;i<results.length;i++)assert.deepStrictEqual(results[i],lua[i]);console.log('PASS exact Pages/Lua preview parity for range edges, gaps and cross-midnight pre-bell');}
 const bad=JSON.parse(rangeRaw);bad.plans[1].start='2026-12-31';assert.equal((await api('preview',{date:'2027-01-01',draft:JSON.stringify(bad)})).code,'invalid');
 bad.plans=JSON.parse(rangeRaw).plans;bad.schedules[0].rows[0].media='user1';assert.equal((await api('preview',{date:'2027-01-01',draft:JSON.stringify(bad)})).code,'invalid');
 const afterResize=await api('journal',{action:'resize',kib:16,expected:32,confirmed:'false'});
 assert(!afterResize.ok);assert((await api('journal',{action:'resize',kib:16,expected:32,confirmed:'true'})).ok);
 assert.equal((await api('journal')).limit_bytes,16384);
 const resources=(await api('automatic')).cpu;assert.equal(resources.available,false);assert.equal(resources.storage,undefined);assert.equal(resources.uptime_seconds,undefined);
 // Exercise the actual Pages API in both scheduling modes with virtual time.
 await api('automatic',{enabled:'false'});
 await api('timezone',{zone:'UTC',revision:(await api('timezone')).revision});
 const virtual={mode:'fixed',fixed_schedule:'lessons',active_plan:'p',pre_minutes:2,pre_media:'test',schedules:[{id:'lessons',name:'Lessons',color:1,rows:[{id:'bell',time:'08:30',media:'test',enabled:true,pre:true}]}],plans:[{id:'p',name:'Plan',start:'2026-11-09',end:'2026-11-10',schedule_ids:['lessons'],days:'AA'}]};
 // Keep the currently protected source until applying the new snapshot.
 let old=(await api('load'));virtual.schedules.push(...old.data.schedules);
 let sv=await api('save',{revision:old.revision,draft:JSON.stringify(virtual)});assert(sv.ok,JSON.stringify(sv));
 let av=await api('automatic',{action:'apply',revision:sv.revision});assert(av.ok);
 await api('simulator',{command:'time',local:'2026-11-09T08:27:00'});
 await api('simulator',{command:'configure',speed:0,audio:'ready',internet:'unconfirmed',ntp:'synced'});
 assert((await api('clock-trust',{action:'resume',revision:sv.revision,generation:String(av.generation)})).ok);
 await api('simulator',{command:'next'});assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-09').count,1);
 await api('simulator',{command:'next'});assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-09').count,2);
 const paired=(await api('journal')).entries.filter(e=>e.action==='auto_ok');assert.equal(paired.length,2);assert.equal(paired[0].bell.kind,'pre');assert.equal(paired[1].bell.kind,'main');assert.equal(paired[0].time,Date.parse('2026-11-09T08:28:00Z')/1000);
 // Repeated reads, rollback and replay never count the same event twice.
 await api('simulator',{command:'time',local:'2026-11-09T08:27:00'});await api('simulator',{command:'step',seconds:3600});
 assert.equal((await api('metrics')).days[0].count,2);
 await api('automatic',{enabled:'false'});virtual.mode='annual';old=await api('load');sv=await api('save',{revision:old.revision,draft:JSON.stringify(virtual)});assert(sv.ok,JSON.stringify(sv));av=await api('automatic',{action:'apply',revision:sv.revision});
 await api('simulator',{command:'time',local:'2026-11-10T08:27:00'});await api('simulator',{command:'configure',speed:0,audio:'missing',internet:'available',ntp:'waiting'});
 await api('clock-trust',{action:'resume',revision:sv.revision,generation:String(av.generation)});
 await api('simulator',{command:'next'});assert((await api('automatic')).enabled);assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-10').count,0);assert((await api('journal')).entries.some(e=>e.action==='auto_audio_unavailable'&&e.level==='error'));
 await api('simulator',{command:'configure',speed:0,audio:'ready',internet:'available',ntp:'waiting'});await api('simulator',{command:'next'});assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-10').count,1);
 const network=(await api('controls')).network;assert.equal(network.internet.state,'available');assert.equal(network.ntp.state,'waiting');
 await api('journal',{action:'clear'});assert.equal((await api('journal')).entries.length,0);assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-10').count,1);
 await api('demo-boot',{});assert(!(await api('automatic')).enabled);assert.equal((await api('simulator')).sim.speed,0);
 assert(!(await api('simulator',{command:'step',seconds:1e12})).ok);assert(!(await api('simulator',{command:'time',local:'nonsense'})).ok);
 // Muting and player errors do not add successful bells or stop automation.
 await api('simulator',{command:'time',local:'2026-11-09T08:27:00'});
 // Use a fresh future fixed day to avoid the rollback deduplication guard.
 await api('automatic',{enabled:'false'});let fixedAgain=(await api('load'));fixedAgain.data.mode='fixed';sv=await api('save',{revision:fixedAgain.revision,draft:JSON.stringify(fixedAgain.data)});av=await api('automatic',{action:'apply',revision:sv.revision});
 await api('simulator',{command:'time',local:'2026-11-11T08:27:00'});await api('clock-trust',{action:'resume',revision:sv.revision,generation:String(av.generation)});
 await api('controls',{muted:'true'});await api('simulator',{command:'next'});assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-11').count,0);
 await api('controls',{muted:'false'});await api('simulator',{command:'configure',speed:0,audio:'error',internet:'available',ntp:'waiting'});await api('simulator',{command:'next'});assert((await api('automatic')).enabled);assert((await api('journal')).entries.some(e=>e.action==='auto_player_failed'));assert.equal((await api('metrics')).days.find(d=>d.date==='2026-11-11').count,0);
 assert(!(await api('simulator',{command:'time',local:'2026-02-30T08:27:00'})).ok);
 // Fast time uses monotonic elapsed time and pauses after a suspended browser.
 await api('simulator',{command:'configure',speed:60,audio:'ready',internet:'available',ntp:'waiting'});let before=(await api('clock')).epoch;demoNow+=1000;assert.equal((await api('clock')).epoch,before+60);demoNow+=11000;assert.equal((await api('simulator')).sim.speed,0);
 const beforeReload=await api('metrics');vm.runInNewContext(fs.readFileSync('site/demo.js','utf8'),context);assert(!(await api('automatic')).enabled);assert.equal((await api('simulator')).sim.speed,0);assert.deepEqual((await api('metrics')).days,beforeReload.days);
 console.log('PASS simulator: fixed/annual pre and main bells, journal timestamps, metrics, rollback dedup, hot audio replacement, network independence, reboot, bounds and suspended clock');
 console.log('PASS demo: local persistence, CAS, midnight/quiet-day preview, mock zone, bounded journal, blocked remote API');
})().catch(e=>{console.error(e);process.exitCode=1;});
