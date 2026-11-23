const assert = require('node:assert/strict');
const F = require('./qml/Flow.js');
const send = (s,type,more={}) => F.transition(s,{type,...more});
function enter(task,expert,scenario) {
 let s=F.initial(expert); s=send(s,'confirm',{value:true});s=send(s,'next');s=send(s,'task',{value:task});s=send(s,'scenario',{value:scenario});s=send(s,'next');
 while(F.pageOf(s).id!=='execute') {
  if(F.pageOf(s).confirm) s=send(s,'confirm',{value:true});
  if(F.pageOf(s).id==='check' && scenario===1) {
   assert(!F.canNext(s));assert.equal(send(s,'next'),s);s=send(s,'recheck');
  }
  s=send(s,'next');
 }
 return s;
}
for(const expert of [false,true]) for(const task of F.choices(expert)) for(let scenario=0;scenario<=4;scenario++) {
 let s=enter(task,expert,scenario), failed=false, verifiedStage=false;
 const start=s.starts;
 for(let n=0;n<80 && F.pageOf(s).id!=='result';n++) {
  const stale=s.generation;
  const paused=send(s,'request',{action:'close'});
  assert.equal(send(paused,'tick',{generation:stale}),paused);
  assert.equal(send(paused,'next'),paused);
  s=send(paused,'dismiss');
  assert.equal(send(s,'tick',{generation:stale}),s);
  if(s.failed) {failed=true; const progress=s.progress;s=send(s,'retry');assert.equal(s.progress,progress);assert.equal(s.starts,start);}
  const before=s;
  s=send(s,'tick',{generation:s.generation});
  assert.equal(before.progress<=s.progress,true);
  if(s.verifying) {verifiedStage=true;assert.equal(F.pageOf(s).id,'execute');assert(!s.verified);}
 }
 assert.equal(F.pageOf(s).id,'result');assert(s.verified);assert(verifiedStage);
 assert.equal(failed,scenario>=2);assert.equal(s.starts,start);
 assert.equal(send(s,'retry'),s);assert.equal(send(s,'back'),s);
 s=send(send(s,'request',{action:'reset'}),'accept');
 assert.equal(s.step,-2);assert(!s.verified);assert(!s.confirmed);assert.equal(s.selectedBundle,'');assert.equal(s.progress,0);
}
// Preparation: confirmations, cancellation and duplicate/stale UI actions.
let s=F.initial();assert.equal(send(s,'next'),s);
s=send(s,'confirm',{value:true});const old=s.revision;
s=send(s,'next');assert.equal(F.transition(s,{type:'next',revision:old}),s);
s=send(s,'back');assert(!s.confirmed);assert(!F.canNext(s));
for(const state of [F.initial(),enter(3,false,0),send(enter(3,false,0),'tick',{generation:-1})]) {
 let p=send(state,'request',{action:'reset'});const kept=send(p,'dismiss');
 assert.equal(kept.step,state.step);assert.equal(kept.progress,state.progress);
 let reset=send(send(state,'request',{action:'reset'}),'accept');
 assert.equal(send(reset,'tick',{generation:state.generation}),reset);
 let closed=send(send(state,'request',{action:'close'}),'accept');assert(closed.closed);assert(!closed.running);
 assert.equal(send(closed,'tick',{generation:closed.generation}),closed);
}
// Changing the task clears bundle and scenario; modes cannot change mid-route.
s=enter(1,true,0);assert.equal(send(s,'mode',{value:false}),s);assert.equal(send(s,'task',{value:2}),s);
s=F.initial(true);s=send(s,'confirm',{value:true});s=send(s,'next');s=send(s,'task',{value:1});s=send(s,'scenario',{value:3});s=send(s,'task',{value:2});assert.equal(s.scenario,0);assert.equal(s.selectedBundle,'');
console.log('PASS: all routes/modes/errors, verification gate, retry without restart, cancel/close, stale ticks and confirmations');
