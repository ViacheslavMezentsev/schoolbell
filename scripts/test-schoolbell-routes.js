// DOM/event fixture for real editor + activation scripts; no router or audio.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..'),ui=process.env.SCHOOLBELL_UI_DIR || path.join(root,'ui/root/www/schoolbell-test');
const clone=x=>JSON.parse(JSON.stringify(x));
function fixture(storage={},initialRevision="r1",loadCodes=[]){
 const all=[],ids=new Map(),listeners={},intervals=[],delays=[];
 class Element{
  constructor(tag='div'){this.tag=tag;this.children=[];this.dataset={};this.style={};this.events={};this.disabled=false;this._value='';this.textContent='';this.files=[];all.push(this);}
  appendChild(e){this.children.push(e);e.parent=this;return e;}
  replaceChildren(...e){this.children.forEach(c=>c.detached=true);this.children=[];e.forEach(c=>this.appendChild(c));}
  get options(){return this.children;}
  get selectedIndex(){return this.children.findIndex(c=>c.value===this.value);}
  get value(){return this._value || (this.tag==='select' && this.children[0]?this.children[0].value:'');}set value(v){this._value=String(v);}
  setAttribute(k,v){this[k]=String(v);}
  addEventListener(k,f){(this.events[k]??=[]).push(f);}
  async fire(k,e={}){for(const f of this.events[k]||[])await f(Object.assign({target:this,preventDefault(){}},e));}
  click(){if(this.disabled)return Promise.resolve();return this.fire('click');}
  focus(){x.focused=this;}select(){}scrollIntoView(){}
  querySelector(s){return this.children.find(x=>s==='[value="annual"]' && x.value==='annual') || new Element();}
 }
 const html=fs.readFileSync(process.env.SCHOOLBELL_UI_DIR?path.join(ui,'../index.html'):path.join(root,'ui/root/usr/lib/lua/luci/view/schoolbell_test.htm'),'utf8');
 for(const match of html.matchAll(/<(\w+)\b[^>]*\bid="([^"]+)"[^>]*>/g))ids.set(match[2],new Element(match[1]));
 const get=id=>{assert(ids.has(id),'missing DOM id '+id);return ids.get(id);};
 const window={addEventListener(k,f){(listeners[k]??=[]).push(f);},dispatchEvent(e){for(const f of listeners[e.type]||[])f(e);},confirm(message){x.confirms++;x.confirmMessages.push(message);return x.confirm;}};
 get('session-panel').dataset.user='root';
 get('schedule-editor').dataset={load:'load',save:'save',preview:'preview',automatic:'auto',token:'test'};
 const document={hidden:false,getElementById:get,createElement:t=>new Element(t),addEventListener(){},querySelectorAll(s){return s==='.calendar-day'?all.filter(e=>!e.detached && (e.className||'').split(' ').includes('calendar-day')):[];}};
 let draft={mode:'annual',fixed_schedule:'quiet',manual_media:'test',pre_media:'test',pre_minutes:2,schedules:[{id:'s',name:'Normal',color:1,rows:[{id:'r',time:'08:00',media:'test',enabled:true,pre:false}]}],plans:[{year:2026,schedule_ids:['s'],days:'A'+'.'.repeat(364)}]};
 const x={get,window,confirms:0,confirm:true,confirmMessages:[],saves:[],posts:[],previews:[],rev:initialRevision,data:draft,active:{state:'disabled',enabled:false},clock:0};
 const fetch=async(url,options={})=>{
  const post=options.method==='POST',body=post?Object.fromEntries(options.body):{};let value;
  if(url==='load'){x.loads=(x.loads || 0)+1;if(x.pauseLoad)await new Promise(resolve=>x.releaseLoad=resolve);if(x.failLoad)throw Error('network');value=loadCodes.length?{ok:false,code:loadCodes.shift()}:{ok:true,data:clone(x.data),revision:x.rev};}
  else if(url==='save'){x.saves.push(body);if(body.revision!==x.rev)value={ok:false,code:'conflict'};else{x.data=JSON.parse(body.draft);x.rev='r2';if(x.loseSave)throw Error('lost response');value={ok:true,data:clone(x.data),revision:x.rev};}}
  else if(url==='preview'){x.previews.push(JSON.parse(body.draft));value={ok:true,date:body.date,selected_schedule:'s',events:[]};}
  else if(url==='auto'){if(post){x.posts.push(body);value=x.reject?{ok:false,code:'conflict'}:{ok:true,generation:x.commandGeneration || 2};}else value=x.active;}
  else throw Error('unexpected URL');return {ok:true,json:async()=>clone(value)};
 };
 window.schoolbellClockCommand=async body=>{assert(['enable','resume'].includes(body.action));x.posts.push(body);if(x.pauseCommand)await new Promise(resolve=>x.releaseCommand=resolve);if(x.reject)throw Error('clock_untrusted');return {ok:true,generation:x.commandGeneration || 2};};
 const ctx={sessionStorage:{getItem:k=>storage[k]||null,setItem:(k,v)=>storage[k]=v,removeItem:k=>delete storage[k]},window,document,fetch,performance:{now:()=>x.clock},Date,Math,Number,String,Array,JSON,URLSearchParams,AbortController,TextEncoder,CustomEvent:class{constructor(type,o={}){this.type=type;this.detail=o.detail;}},setTimeout:(f,ms)=>{if(ms===500 || ms===1000)delays.push(f);return 1;},clearTimeout(){},setInterval:f=>intervals.push(f)};
 vm.createContext(ctx);for(const file of ['ranges.js','automatic.js','schedules.js'])vm.runInContext(fs.readFileSync(path.join(ui,file),'utf8'),ctx);
 x.tick=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};x.poll=async()=>{for(const f of intervals)await f();await x.tick();};
 x.retry=async()=>{assert(delays.length);delays.shift()();await x.tick();};
 x.day=()=>all.filter(e=>e.dataset.date==='2026-01-01' && !e.detached).at(-1);
 x.brush=name=>get('plan-legend').children.find(e=>e.textContent===name);
 return x;
}
(async()=>{
 // TC-195: compare rendered controls against the normative table, including persisted IDs.
 const spec=fs.readFileSync(path.join(root,'docs/requirements/TECHNICAL_SPECIFICATION.md'),'utf8');
 const baseline=Array.from(spec.matchAll(/\| (\d+) \| `([a-z]+)` \| `(#[0-9A-F]{6})` \|/g),m=>({id:Number(m[1]),name:m[2],hex:m[3].toLowerCase()}));
 assert.equal(baseline.length,16);
 const palette=fixture();await palette.tick();
 for(const c of baseline){
  const buttons=palette.get('schedule-colors').children;assert.equal(buttons.length,16);
  const button=buttons[c.id-1];assert.equal(button.textContent,c.id);assert.equal(button.style.background,c.hex);assert(button.title.includes('('+c.name+')'));
  const rgb=c.hex.slice(1).match(/../g).map(v=>parseInt(v,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);
  const l=rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;
  assert((button.style.color==='#ffffff'?1.05/(l+.05):(l+.05)/.05)>=4.5);
  await button.click();assert.equal(palette.day().style.background,c.hex);assert.equal(palette.get('schedule-select').style.borderLeft,'10px solid '+c.hex);
  palette.data.schedules[0].color=c.id;await palette.get('schedule-reload').click();assert.equal(palette.get('schedule-colors').children[c.id-1]['aria-pressed'],'true');
 }
 assert.equal(palette.saves.length,0);assert.equal(palette.posts.length,0);
 console.log('PASS TC-195: exact specification palette order/names/HEX, contrast, selection/calendar and reloaded IDs; no writes or activation');
 if(process.env.SCHOOLBELL_PAGES_TEST){const p=fixture();await p.tick();const snap=p.window.schoolbellEditor.portableSnapshot();snap.draft.schedules[0].name='External mutation';assert.notEqual(p.window.schoolbellEditor.portableSnapshot().draft.schedules[0].name,'External mutation');p.get('plan-name').value='Pending';await p.get('plan-name').fire('input');assert(p.window.schoolbellEditor.portableSnapshot().formPending);assert(!p.saves.length&&!p.posts.length);console.log('PASS Pages-only read snapshot is cloned and identifies unapplied plan fields');}
 let b=fixture({},'r1',['busy','busy']);await b.tick();
 assert.equal(b.loads,1);assert(!b.window.schoolbellEditor.snapshot().loaded);
 await b.retry();assert.equal(b.loads,2);await b.retry();assert.equal(b.loads,3);
 assert(b.window.schoolbellEditor.snapshot().loaded);assert(!b.get('schedule-fields').disabled);
 assert.equal(b.saves.length,0);assert.equal(b.posts.length,0);
 b=fixture({},'r1',['busy','busy','busy']);await b.tick();await b.retry();await b.retry();
 assert(!b.window.schoolbellEditor.snapshot().busy);assert(!b.get('schedule-reload').disabled);
 assert(b.get('schedule-result').textContent.includes('ещё не загружен'));
 await b.get('schedule-reload').click();assert(b.window.schoolbellEditor.snapshot().loaded);
 b=fixture({},'r1',['storage_unavailable']);await b.tick();assert.equal(b.loads,1);
 assert(!b.window.schoolbellEditor.snapshot().loaded);
 b=fixture({},'r1',['busy']);await b.tick();b.window.schoolbellSessionBlocked=true;
 b.window.dispatchEvent({type:'schoolbell-session-lost'});await b.retry();assert.equal(b.loads,1);
 assert(!b.window.schoolbellEditor.snapshot().loaded);
 b=fixture();await b.tick();b.pauseLoad=true;let reading=b.get('schedule-reload').click();await b.tick();
 b.get('schedule-name').value='Concurrent edit';await b.get('schedule-name').fire('input');
 b.releaseLoad();await reading;assert.equal(b.get('schedule-name').value,'Concurrent edit');
 assert(b.window.schoolbellEditor.snapshot().reconcile);assert.equal(b.saves.length,0);
 b=fixture();await b.tick();b.pauseLoad=true;reading=b.get('schedule-reload').click();await b.tick();
 b.window.dispatchEvent({type:'schoolbell-session-lost'});b.releaseLoad();await reading;
 assert(b.window.schoolbellEditor.snapshot().reconcile);
 const codes=[];b=fixture({},'r1',codes);await b.tick();
 b.get('schedule-name').value='Keep after busy';await b.get('schedule-name').fire('input');
 codes.push('busy','busy','busy');reading=b.get('draft-compare').click();await b.tick();await b.retry();await b.retry();await reading;
 assert.equal(b.get('schedule-name').value,'Keep after busy');assert(b.window.schoolbellEditor.snapshot().dirty);
 assert(!b.get('draft-compare').disabled);await b.get('draft-compare').click();
 assert.equal(b.get('schedule-name').value,'Keep after busy');assert.equal(b.saves.length,0);
 console.log('PASS draft recovery: bounded busy GET retry, explicit retry, storage failure, session loss, concurrent edits, no POST');

 let h=fixture();await h.tick();
 assert(h.get('quick-automatic').disabled);assert.equal(h.get('quick-automatic-status').dataset.tone,'danger');
 h.active={ok:true,state:'disabled',enabled:false,generation:1,revision:'applied',mode:'fixed'};await h.poll();assert(h.get('quick-automatic').textContent.includes('☷'));h.active.mode='annual';await h.poll();assert(h.get('quick-automatic').textContent.includes('📅'));
 assert(!h.get('quick-automatic').disabled);assert.equal(h.get('quick-automatic-status').textContent,'Выключены');
 h.window.schoolbellEditor.snapshot().dirty=true;
 // Deliberately edit the real draft; header resume must not load or apply it.
 h.get('schedule-name').value='Unsaved name';await h.get('schedule-name').fire('input');
 const saves=h.saves.length;h.failLoad=true;
 await h.get('quick-automatic').click();await h.tick();
 assert.equal(h.posts.length,1);assert.equal(h.posts[0].action,'resume');assert.equal(h.posts[0].revision,'applied');assert.equal(h.posts[0].generation,'1');assert.equal(h.saves.length,saves);
 assert(h.get('quick-automatic').disabled);assert(h.get('quick-automatic-status').textContent.includes('подтверждения'));
 await h.poll();assert(h.get('quick-automatic').disabled); // Old generation cannot confirm.
 h.active={ok:true,state:'running',enabled:true,generation:2,revision:'applied'};await h.poll();
 assert.equal(h.get('quick-automatic-status').dataset.tone,'success');assert.equal(h.get('quick-automatic-status').textContent,'Работают');
 assert.equal(h.get('schedule-name').value,'Unsaved name');assert(!h.get('automatic-status').textContent.includes('Ожидаем подтверждения'));
 h.commandGeneration=3;await h.get('quick-automatic').click();await h.tick();assert.equal(h.posts[1].enabled,'false');
 h.active={ok:true,state:'disabled',enabled:false,generation:3,revision:'applied'};await h.poll();assert.equal(h.get('quick-automatic-status').textContent,'Выключены');assert(!h.get('automatic-status').textContent.includes('Ожидаем подтверждения'));
 h.active={ok:true,state:'muted',enabled:true,generation:3,revision:'applied'};await h.poll();assert.equal(h.get('quick-automatic-status').dataset.tone,'warning');
 h.active.state='clock_untrusted';await h.poll();assert.equal(h.get('quick-automatic-status').dataset.tone,'danger');assert(!h.get('quick-automatic').disabled);
 h.active.state='waiting';await h.poll();assert(h.get('quick-automatic').disabled);assert.equal(h.get('quick-automatic-status').textContent,'Нет свежих данных');
 h.window.schoolbellSessionBlocked=true;h.window.dispatchEvent({type:'schoolbell-session-lost'});assert(h.get('quick-automatic').disabled);assert.equal(h.get('quick-automatic-status').textContent,'Войдите');
 h=fixture();await h.tick();h.active={ok:true,state:'disabled',enabled:false,generation:0};await h.poll();await h.get('quick-automatic').click();assert.equal(h.posts.length,0);assert(h.get('automatic-status').textContent.includes('Сначала примените'));
 h.active={ok:true,state:'disabled',enabled:false,generation:1,revision:'applied'};h.reject=true;await h.poll();await h.get('quick-automatic').click();await h.tick();assert.equal(h.posts.length,1);await h.poll();assert.equal(h.posts.length,1);
 h=fixture();await h.tick();h.active={ok:true,state:'disabled',enabled:false,generation:1,revision:'applied'};await h.poll();
 await h.get('quick-automatic').click();await h.tick();h.clock=20000;await h.poll();
 assert.equal(h.posts.length,1);assert(h.get('automatic-status').textContent.includes('Подтверждение не получено'));
 h=fixture();await h.tick();h.active={ok:true,state:'disabled',enabled:false,generation:1,revision:'applied'};await h.poll();h.pauseCommand=true;
 const pendingResume=h.get('quick-automatic').click();await h.tick();h.window.schoolbellSessionBlocked=true;h.window.dispatchEvent({type:'schoolbell-session-lost'});h.releaseCommand();await pendingResume;
 assert(h.get('quick-automatic').disabled);assert.equal(h.get('quick-automatic-status').textContent,'Войдите');assert.equal(h.posts.length,1);
 console.log('PASS header: applied-only resume, dirty draft retained, confirmed generation, stop, colors, missing plan/session and no replay');

 let y=fixture();await y.tick();
 const R=require('../ui/root/www/schoolbell-test/ranges.js');
 const range=(start,end)=>({id:'p',name:'Range',start,end,schedule_ids:['s'],days:'.'.repeat(R.dates(start,end).length)});
 const visible=()=>y.get('year-grid').children.flatMap(m=>m.children[1].children.filter(d=>d.dataset.date));
 y.data.plans=[range('2027-12-31','2028-01-02')];await y.get('schedule-reload').click();
 assert.deepStrictEqual(visible().map(d=>d.dataset.date),['2027-12-31','2028-01-01','2028-01-02']);assert(y.get('months-navigation').hidden);assert(y.get('months-bottom-navigation').hidden);
 y.data.plans=[range('2027-09-01','2028-09-02')];await y.get('schedule-reload').click();
 assert.equal(y.get('year-grid').children.length,12);assert.equal(visible()[0].dataset.date,'2027-09-01');assert.equal(visible().at(-1).dataset.date,'2028-08-31');
 assert(y.get('months-prev').disabled);assert(!y.get('months-next').disabled);assert(!y.window.schoolbellEditor.snapshot().dirty);
 await y.get('months-next').click();assert.equal(y.get('year-grid').children.length,1);assert.deepStrictEqual(visible().map(d=>d.dataset.date),['2028-09-01','2028-09-02']);assert(y.get('months-next').disabled);assert(!y.window.schoolbellEditor.snapshot().dirty);
 await y.brush('Normal').click();await visible()[1].click();assert(y.window.schoolbellEditor.snapshot().dirty);
 await y.get('months-prev').click();await y.get('months-next').click();assert.equal(visible()[1].title,'2028-09-02 · Normal');assert.equal(y.saves.length,0);assert.equal(y.posts.length,0);
 assert(y.get('months-bottom-next').disabled);assert.equal(y.get('months-bottom-status').textContent,y.get('months-status').textContent);
 await y.get('months-bottom-prev').click();assert(y.get('months-prev').disabled && y.get('months-bottom-prev').disabled);assert(!y.get('months-next').disabled && !y.get('months-bottom-next').disabled);
 await y.get('months-bottom-next').click();assert.equal(visible()[1].title,'2028-09-02 · Normal');assert(y.get('months-next').disabled && y.get('months-bottom-next').disabled);
 assert.equal(y.saves.length,0);assert.equal(y.posts.length,0);
 console.log('PASS consecutive cross-year months; bounded pages; navigation preserves draft and global assignment indices');
 let x=fixture();await x.tick();
 assert(x.brush('Просмотр дня')['aria-pressed']==='true');
 await x.day().fire('pointerdown',{pointerType:'mouse',button:0});await x.day().click();await x.tick();
 assert(x.previews.length===1 && x.previews[0].plans[0].days[0]==='A');assert(!x.window.schoolbellEditor.snapshot().dirty);
 assert(x.get('preview-status').textContent.startsWith('Черновик'));console.log('PASS view date does not mutate; preview explicitly draft');
 await x.brush('Тихий день / ластик').click();await x.day().click();assert(x.window.schoolbellEditor.snapshot().dirty);assert(x.get('automatic-enable').disabled);
 await x.get('automatic-enable').fire('click');assert(!x.posts.length && !x.confirms);
 await x.get('workflow-save').click();await x.tick();assert(x.data.plans[0].days[0]==='.');assert(!x.posts.length);assert(!x.get('automatic-enable').disabled);
 console.log('PASS explicit erase, dirty gate, shared save never activates');
 x.active={state:'running',revision:'r1',mode:'annual'};await x.poll();assert(x.get('workflow-difference').textContent.includes('отличается'));
 x.pauseLoad=true;const applying=x.get('automatic-enable').click();await x.tick();assert(x.get('schedule-fields').disabled && x.get('manual-media').disabled);x.rev='other';x.releaseLoad();await applying;await x.tick();
 assert(!x.posts.length && !x.confirms && !x.get('schedule-fields').disabled);assert(x.get('automatic-status').textContent.includes('другом окне'));
 console.log('PASS active differs, frozen editor during apply, concurrent revision rejected');
 x=fixture();await x.tick();await x.get('automatic-enable').click();await x.tick();assert(x.confirms===1 && x.posts.length===1 && x.posts[0].revision==='r1');assert(x.get('workflow-active').textContent.includes('неизвестно'));
 x.active={state:'running',revision:'r1',mode:'annual'};await x.poll();assert(x.get('workflow-difference').textContent.includes('соответствует'));
 x.clock=16000;await x.poll(); // poll refreshes; force only draw below via editor event
 x.clock=32000;x.window.dispatchEvent({type:'schoolbell-editor-state'});assert(x.get('workflow-active').textContent.includes('неизвестно'));
 x.active={state:'waiting',enabled:false,revision:'r1'};await x.poll();assert(x.get('workflow-active').textContent.includes('выключены'));
 console.log('PASS explicit apply, wait for service confirmation, stale status not active');
 for(const flag of ['confirm','failLoad','reject']){x=fixture();await x.tick();x[flag]=flag==='confirm'?false:true;await x.get('automatic-enable').click();await x.tick();assert(!x.get('schedule-fields').disabled);if(flag!=='reject')assert(!x.posts.length);}
 x=fixture();await x.tick();x.get('schedule-name').value='Edited';await x.get('schedule-name').fire('input');await x.get('automatic-disable').click();await x.tick();assert(x.posts[0].enabled==='false');
 console.log('PASS cancel/read/POST failures unlock; disable allowed with unsaved changes');
 x=fixture();await x.tick();x.get('schedule-name').value='Keep local';await x.get('schedule-name').fire('input');x.window.schoolbellSessionBlocked=true;x.window.dispatchEvent({type:'schoolbell-session-lost'});assert(x.get('schedule-name').value==='Keep local' && x.window.schoolbellEditor.snapshot().dirty && x.window.schoolbellEditor.snapshot().reconcile);assert(!x.saves.length && !x.posts.length);
 await x.poll();assert(x.get('automatic-enable').disabled && x.get('automatic-disable').disabled);assert.equal(x.get('duty-compact').textContent,'Войдите для просмотра состояния');
 console.log('PASS session loss retains edits and requires reconciliation without POST');
 const stash={};x=fixture(stash);await x.tick();x.get('schedule-name').value='Keep through login';await x.get('schedule-name').fire('input');assert(x.window.schoolbellEditor.prepareNavigation());assert(!JSON.stringify(stash).includes('token'));let resumed=fixture(stash);await resumed.tick();assert(resumed.get('schedule-name').value==='Keep through login' && resumed.window.schoolbellEditor.snapshot().dirty);assert(!resumed.posts.length && !resumed.saves.length && Object.keys(stash).length===0);
 console.log('PASS same-tab login restores unsaved draft without POST; handoff consumed without secrets');
 x=fixture(stash);await x.tick();x.data.schedules.push({id:'s2',name:'Second',color:2,rows:[]});await x.get('schedule-reload').click();x.get('schedule-select').value='s2';await x.get('schedule-select').fire('change');x.get('schedule-name').value='Second edited';await x.get('schedule-name').fire('input');assert(x.window.schoolbellEditor.prepareNavigation());resumed=fixture(stash);await resumed.tick();assert.equal(resumed.get('schedule-name').value,'Second edited');
 const broken=new Proxy({}, {set(){throw Error('quota');}});x=fixture(broken);await x.tick();x.get('schedule-name').value='Stay here';await x.get('schedule-name').fire('input');assert.strictEqual(x.window.schoolbellEditor.prepareNavigation(),false);assert.equal(x.get('schedule-name').value,'Stay here');
 console.log('PASS selected schedule restored; storage quota failure retains editor and cancels handoff');

 for(const bad of ['user','expiry']){x=fixture(stash);await x.tick();x.get('schedule-name').value='Private';await x.get('schedule-name').fire('input');assert(x.window.schoolbellEditor.prepareNavigation());const key=Object.keys(stash)[0],v=JSON.parse(stash[key]);if(bad==='user')v.user='other';else v.until=0;stash[key]=JSON.stringify(v);resumed=fixture(stash);await resumed.tick();assert(resumed.get('schedule-name').value==='Normal' && !resumed.window.schoolbellEditor.snapshot().dirty);}
 x=fixture(stash);await x.tick();x.get('schedule-name').value='Preserved conflict';await x.get('schedule-name').fire('input');assert(x.window.schoolbellEditor.prepareNavigation());resumed=fixture(stash,'r2');await resumed.tick();assert(resumed.get('schedule-name').value==='Preserved conflict' && resumed.window.schoolbellEditor.snapshot().reconcile && !resumed.saves.length);
 console.log('PASS expired/foreign handoff discarded; changed revision retains edits but requires comparison');


 x=fixture();await x.tick();await x.get('plan-new').click();assert.equal(x.get('plan-start').value,'');assert(x.get('schedule-save').disabled);
 const set=async(id,v)=>{x.get(id).value=v;await x.get(id).fire('input');};
 await set('plan-name','Учебный 2026–2027');await set('plan-start','2026-12-31');await set('plan-end','2028-01-01');await x.get('plan-apply').click();assert(x.get('plan-form-status').textContent.includes('пересекается'));assert(x.get('schedule-save').disabled);
 await set('plan-start','2027-01-01');await x.get('plan-apply').click();assert(x.get('plan-form-status').textContent.includes('черновике'));await x.get('schedule-save').click();assert.equal(x.data.plans.length,2);assert.equal(x.data.plans[1].days.length,366);assert(!x.posts.length);
 await set('plan-name','Новый заголовок');await set('plan-start','2027-01-02');await x.get('plan-apply').click();await x.get('schedule-save').click();assert.equal(x.data.plans[1].name,'Новый заголовок');assert.equal(x.data.plans[1].days.length,365);
 const stable=x.data.plans[1].id;await x.get('schedule-reload').click();assert.equal(x.get('calendar-plan').value,stable);assert.equal(x.get('plan-start').value,'2027-01-02');
 await x.get('plan-new').click();await set('plan-start','2020-01-01');await set('plan-end','2099-01-01');await x.get('plan-apply').click();assert(x.get('plan-form-status').textContent.includes('12 КиБ'));assert.equal(x.data.plans.length,2);await x.get('plan-cancel').click();
 x.data.plans=[];x.data.mode='fixed';await x.get('schedule-reload').click();assert.equal(x.get('plan-start').value,'');assert(x.get('months-navigation').hidden);assert(x.get('plan-status').textContent.includes('ещё не создан'));
 x.window.dispatchEvent({type:'schoolbell-router-date',detail:'2026-10-26'});x.window.dispatchEvent({type:'schoolbell-clock-state',detail:{state:'confirmed'}});await x.get('plan-new').click();assert.equal(x.get('plan-start').value,'2026-09-01');assert.equal(x.get('plan-end').value,'2027-05-31');assert(!x.data.plans.length);
 console.log('PASS range editor: no phantom year, trusted proposal only, overlap refusal, persisted name/range, stable ID, actual size rejection and no activation');
 // C1: rendering never changes mode or fixed selection behind the user's back.
 x=fixture();await x.tick();x.data.mode='fixed';x.data.fixed_schedule='s';x.data.plans=[];await x.get('schedule-reload').click();
 await x.get('schedule-delete').click();assert(x.get('schedule-select').options.length===1);assert(!x.window.schoolbellEditor.snapshot().dirty);assert(x.get('schedule-result').textContent.includes('ежедневное'));assert(x.confirms===0);
 x.get('fixed-schedule').value='quiet';await x.get('fixed-schedule').fire('change');await x.get('schedule-delete').click();assert(x.get('schedule-select').options.length===0);assert(!x.posts.length && !x.saves.length);
 console.log('PASS fixed reference requires explicit replacement before deletion');
 x=fixture();await x.tick();await x.get('schedule-delete').click();assert(x.get('schedule-result').textContent.includes('во всех планах'));assert(x.confirms===0);
 x.confirm=false;await x.get('year-clear').click();assert(x.get('work-mode').value==='annual');assert(!x.window.schoolbellEditor.snapshot().dirty);assert(x.confirmMessages.at(-1).includes('последний план'));
 x.confirm=true;await x.get('year-clear').click();assert(x.get('work-mode').value==='fixed' && x.get('fixed-schedule').value==='quiet');assert(x.window.schoolbellEditor.snapshot().dirty);assert(!x.saves.length && !x.posts.length);
 console.log('PASS calendar dependencies and explicit last-year mode transition; cancel preserves draft');
 x=fixture();await x.tick();x.get('schedule-name').value='Local';await x.get('schedule-name').fire('input');x.data.schedules[0].name='Remote';x.rev='other';
 await x.get('schedule-save').click();assert(x.window.schoolbellEditor.snapshot().reconcile);assert(x.get('schedule-name').value==='Local');
 await x.get('draft-compare').click();assert(x.get('draft-local-json').textContent.includes('Local'));assert(x.get('draft-router-json').textContent.includes('Remote'));assert(x.get('schedule-name').value==='Local');assert(x.get('automatic-enable').disabled);
 x.confirm=false;await x.get('draft-keep-local').click();assert(x.window.schoolbellEditor.snapshot().reconcile);
 x.confirm=true;await x.get('draft-keep-local').click();assert(x.window.schoolbellEditor.snapshot().revision==='other' && x.window.schoolbellEditor.snapshot().dirty);assert(x.saves.length===1 && !x.posts.length);
 x.rev='third';await x.get('schedule-save').click();assert(x.window.schoolbellEditor.snapshot().reconcile && x.data.schedules[0].name==='Remote');
 await x.get('draft-compare').click();await x.get('draft-use-router').click();assert(x.get('schedule-name').value==='Remote');assert(!x.window.schoolbellEditor.snapshot().dirty && !x.window.schoolbellEditor.snapshot().reconcile);assert(!x.posts.length);
 console.log('PASS conflict comparison preserves local copy; explicit choices; subsequent CAS still enforced');
 x=fixture();await x.tick();x.get('schedule-name').value='Saved despite lost reply';await x.get('schedule-name').fire('input');x.loseSave=true;await x.get('schedule-save').click();assert(x.window.schoolbellEditor.snapshot().reconcile);
 await x.get('draft-compare').click();assert(x.get('draft-comparison-status').textContent.includes('совпадают'));await x.get('draft-keep-local').click();assert(!x.window.schoolbellEditor.snapshot().dirty && x.saves.length===1 && !x.posts.length);
 console.log('PASS lost successful save reconciles without repeated POST');
 x=fixture();await x.tick();x.get('schedule-name').value='<img src=x onerror=bad()>';await x.get('schedule-name').fire('input');x.failLoad=true;await x.get('draft-compare').click();assert(x.get('schedule-name').value.includes('<img'));assert(x.window.schoolbellEditor.snapshot().dirty && x.window.schoolbellEditor.snapshot().reconcile);assert(!x.get('schedule-fields').disabled);
 x.failLoad=false;await x.get('draft-compare').click();assert(x.get('draft-local-json').textContent.includes('<img'));assert(x.get('draft-local-json').children.length===0);
 x.get('schedule-name').value='New edit';await x.get('schedule-name').fire('input');assert(x.get('draft-comparison').hidden && x.get('draft-use-router').disabled);assert(!x.saves.length && !x.posts.length);
 console.log('PASS failed comparison preserves edits; content is text; edits invalidate stale comparison');
 x=fixture();await x.tick();const listens=[];x.window.schoolbellRowPreview=(id,hw)=>listens.push([id,hw]);
 const row=x.get('schedule-rows').children[0];assert.equal(row.children.length,4);
 const switches=row.children[2].children[0].children;assert.equal(switches.length,2);assert.equal(switches[0].checked,true);assert.equal(switches[1].checked,false);
 switches[1].checked=true;await switches[1].fire('change');assert.equal(x.window.schoolbellEditor.exportSnapshot().draft.schedules[0].rows[0].pre,true);
 const media=row.children[1].children[0];media.value='user3';await media.fire('change');
 const actions=row.children[3].children[0].children;assert.equal(actions.length,6);assert.equal(actions[5].className,'icon-delete');await actions[3].click();await actions[4].click();
 assert.deepEqual(listens,[['user3',false],['user3',true]]);assert(!x.saves.length && !x.posts.length);
 console.log('PASS row preview uses current unsaved selection without save or activation');
 // TC-196: real handlers preserve whole rows and their order; edits never activate or write implicitly.
 x=fixture();await x.tick();
 const rowButtons=i=>x.get('schedule-rows').children[i].children[3].children[0].children;
 const snapshot=()=>clone(x.window.schoolbellEditor.exportSnapshot().draft.schedules[0].rows);
 assert(rowButtons(0)[1].disabled && rowButtons(0)[2].disabled);
 await rowButtons(0)[0].click();
 assert.equal(snapshot().length,2);assert.equal(x.focused,x.get('schedule-rows').children[1].children[0].children[0]);
 const added=snapshot()[1];assert.notEqual(added.id,'r');assert.equal(added.time,'08:00');
 await rowButtons(0)[0].click();
 const initial=snapshot();assert.equal(initial[0].id,'r');assert.equal(initial[2].id,added.id);
 await rowButtons(1)[2].click();assert.deepEqual(snapshot(),[initial[0],initial[2],initial[1]]);
 await rowButtons(2)[1].click();assert.deepEqual(snapshot(),initial);
 await rowButtons(0)[1].click();await rowButtons(2)[2].click();assert.deepEqual(snapshot(),initial);
 assert.equal(x.saves.length,0);assert.equal(x.posts.length,0);
 await x.get('schedule-save').click();await x.get('schedule-reload').click();assert.deepEqual(snapshot(),initial);
 x.window.schoolbellSessionBlocked=true;await rowButtons(0)[0].click();await rowButtons(0)[2].click();assert.deepEqual(snapshot(),initial);x.window.schoolbellSessionBlocked=false;
 x.confirm=false;await x.get('rows-clear').click();assert.deepEqual(snapshot(),initial);
 x.confirm=true;await rowButtons(1)[5].click();assert.deepEqual(snapshot(),[initial[0],initial[2]]);
 await x.get('rows-clear').click();assert.equal(snapshot().length,0);assert.equal(x.window.schoolbellEditor.exportSnapshot().draft.schedules.length,1);
 await x.get('row-add').click();assert.equal(snapshot().length,1);assert(rowButtons(0)[1].disabled && rowButtons(0)[2].disabled);
 assert.equal(x.saves.length,1);assert.equal(x.posts.length,0);
 console.log('PASS TC-196: insert after, focus, move boundaries/order/fields, explicit save/reload, blocked session, delete/clear cancel and empty-list recovery');

 x=fixture();await x.tick();
 for(let i=1;i<129;i++)await x.get('row-add').click();
 assert.equal(x.get('schedule-rows').children.length,129);
 assert.equal(x.get('schedule-rows').children.length,129);
 assert(!x.get('row-add').disabled && !x.get('schedule-copy').disabled);
 assert(!x.posts.length);
 console.log('PASS real editor allows adding beyond 32/128, count has no quota and no activation');

})().catch(e=>{console.error(e);process.exitCode=1;});
