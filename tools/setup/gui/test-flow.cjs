const assert = require('node:assert/strict');
const {routes, phase, shouldFail, equipment, choices, errorText, routeFor} = require('./qml/Flow.js');
assert.equal(routes.length, 4);
for (const [task, route] of routes.entries()) {
 const ids = route.steps.map(s => s.id);
 assert.equal(new Set(ids).size, ids.length);
 assert(ids.indexOf('backup') < ids.indexOf('execute'));
 assert(ids.indexOf('check') < ids.indexOf('execute'));
 assert.equal(ids.at(-1), 'result');
 for (const step of route.steps) {
  assert(step.title && step.text);
  if (/Reset|RESET/.test(step.text)) assert.equal(step.resetPhoto, true);
 }
 if (task === 1) {
  assert(!ids.includes('reset'));
  assert(!route.steps.some(s => s.resetPhoto));
 } else if(task===3) { assert(ids.indexOf('poweroff') < ids.indexOf('hold')); assert(ids.indexOf('hold') < ids.indexOf('poweron')); assert(ids.indexOf('poweron') < ids.indexOf('release')); assert(ids.indexOf('release') < ids.indexOf('execute')); } else assert(ids.indexOf('reset') < ids.indexOf('execute'));
 for (let progress=0; progress<=100; progress+=2) {
  assert(!shouldFail(task, 0, progress));
  assert(!shouldFail(task, 1, progress));
  if (task===2) assert(!/SSH|пакет/.test(phase(task,progress)));
  if (task===1) assert(!/образ|загруз|сети/.test(phase(task,progress)));
 }
 for (const scenario of [2,3]) {
  const stop = Array.from({length:51}, (_,i)=>i*2).find(p=>shouldFail(task,scenario,p));
  assert(stop>0 && stop<100);
 }
}
assert.match(routes[2].steps.at(-1).text, /прежним паролем/);
assert.match(routes[2].steps.at(-1).text, /отдельный сброс/);
assert.match(equipment.text, /USB–Ethernet/);
assert.equal(choices(false)[0], 3);
assert.deepEqual(choices(true), [3,0,1,2]);
assert.match(errorText(3,3,false), /повторно не записывается/);
assert.match(phase(3,70), /Школьник/);
assert.equal(routeFor(2,false).steps.length,10);
assert(!routeFor(2,false).steps.some(s=>/SSH|DHCP|OEM/.test(s.text)));
assert.equal(routeFor(2,true),routes[2]);
console.log('PASS: guided/expert choices, equipment, route isolation, recovery hints and errors');
