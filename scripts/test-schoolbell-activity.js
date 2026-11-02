const assert=require('node:assert/strict');
const {model}=require('../ui/root/www/schoolbell-test/activity.js');
const value={ok:true,today:'2026-11-02',days:[{date:'2026-11-02',count:3},{date:'2026-11-01',count:0},{date:'2026-10-31',count:18}]};
const m=model(value);assert.equal(m.days.length,231);assert.equal(m.days.find(d=>d.date==='2026-11-02').count,3);assert.equal(m.days.find(d=>d.date==='2026-11-01').count,0);assert.equal(m.days.find(d=>d.date==='2026-10-30').count,null);assert.equal(m.days.filter(d=>d.future).length,6);assert.equal(new Date(m.start+'T00:00Z').getUTCDay(),1);
assert.equal(model({ok:true,today:'2024-02-29',days:[]}).today,'2024-02-29');
for(const bad of [{...value,today:'2026-02-30'},{...value,ok:false},{...value,days:[{date:'2026-11-02',count:-1}]},{...value,days:[value.days[0],value.days[0]]}])assert.throws(()=>model(bad));
assert.equal(model({...value,persistence_pending:true}).pending,true);assert.equal(model({...value,demo:true}).demo,true);
console.log('PASS activity model: local calendar, leap date, count/zero/unknown/future, malformed data and persistence warning');
