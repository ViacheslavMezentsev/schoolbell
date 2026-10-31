const assert=require('assert'),M=require('../ui/root/www/schoolbell-test/ranges.js');
const plan=(id,start,end)=>({id,name:id,start,end,schedule_ids:['s'],days:'A'.repeat(M.dates(start,end).length)});
assert(M.dates('2026-09-01','2027-05-31').length===273);assert(M.dates('2027-09-01','2028-05-31').length===274);
assert.throws(()=>M.dates('2027-02-29','2027-03-01'));assert.throws(()=>M.dates('2027-01-02','2027-01-01'));
assert.throws(()=>M.validate([plan('one','2026-09-01','2027-05-31'),plan('two','2027-05-31','2027-06-03')]));
assert(M.validate([plan('one','2026-09-01','2027-05-31'),plan('two','2027-06-01','2027-06-03')]));
let p=plan('a','2026-12-30','2027-01-02'),cut=M.resize(p,'2026-12-31','2027-01-03','Renamed');assert(cut.removed===1 && cut.plan.days==='AAA.' && cut.plan.id==='a');
const old={year:2028,schedule_ids:['s'],days:'A'+'.'.repeat(365)},copy=M.migrate([old])[0];assert(copy.start==='2028-01-01'&&copy.end==='2028-12-31'&&copy.days===old.days);assert(old.year===2028&&!old.start);
assert.throws(()=>M.validate(Array.from({length:9},(_,i)=>plan('p'+i,(2000+i)+'-01-01',(2000+i)+'-01-01'))));
assert(M.validate([plan('a','2000-01-01','2007-12-31'),plan('b','2010-01-01','2010-01-10')]));
assert(M.validate([plan('long','2026-09-01','2046-05-31')]));
console.log('PASS no fixed day quota: multi-plan total above 2928 and a twenty-year range');
assert.throws(()=>M.validate([{...p,days:'ZZZZ'}]));assert.throws(()=>M.validate([{...p,name:' '}]))
console.log('PASS range prototype: academic season/leap, inclusive overlap/adjacency, crop/preserve/extend, stable ID, legacy copy, quotas and codes');

assert.strictEqual(M.suggest('1901-01-01',false),null);assert.strictEqual(M.suggest('',false),null);
assert.deepStrictEqual(M.suggest('2026-10-26',true),{name:'Учебный год 2026–2027',start:'2026-09-01',end:'2027-05-31'});
assert.equal(M.suggest('2027-05-31',true).start,'2026-09-01');assert.equal(M.suggest('2027-08-31',true).start,'2026-09-01');assert.equal(M.suggest('2027-09-01',true).start,'2027-09-01');
console.log('PASS first-install proposal: no trusted date, no implicit year; academic boundary; no plan created');

assert.equal(M.dates("2026-12-31","2028-01-01").length,367);assert(M.validate([plan("three-years","2026-12-31","2028-01-01")]));
console.log("PASS user range 2026-12-31 to 2028-01-01: 367 inclusive days across three years");

for(const plans of [false,0,'']) assert.throws(()=>M.validateDraft({schedules:[],pre_minutes:2,pre_media:'test',plans},true));

const largeDraft={schedules:[{id:'school',name:'School',rows:Array.from({length:129},(_,i)=>({id:'r'+i,time:'09:00',media:'test',enabled:true,pre:false}))}],pre_minutes:2,pre_media:'test',plans:[]};
assert(M.validateDraft(largeDraft,true));
largeDraft.schedules[0].rows[128].id='r0';
assert.throws(()=>M.validateDraft(largeDraft,true));
console.log('PASS row counts above 32/128 accepted; duplicate IDs rejected');
