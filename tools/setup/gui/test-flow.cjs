const assert = require('node:assert/strict');
const {routes, phase, shouldFail} = require('./qml/Flow.js');
assert.equal(routes.length, 3);
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
 } else assert(ids.indexOf('reset') < ids.indexOf('execute'));
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
console.log('PASS: three isolated routes, recovery hints, operation boundaries and error thresholds');
