const fs=require('fs'),vm=require('vm'),assert=require('assert');
const code=fs.readFileSync('ui/root/www/schoolbell-test/automatic.js','utf8');
let e={loaded:true,revision:'a'},v={revision:'a'},now=0;
const elements={'draft-workflow':{},'workflow-draft':{}};
const c={editor:()=>e,confirmed:()=>v,performance:{now:()=>now},document:{getElementById:id=>elements[id]}};
vm.createContext(c);
vm.runInContext(code.slice(code.indexOf('var workflowNeeded='),code.indexOf('function draw(){')),c);
function draw(){vm.runInContext('workflow()',c);return elements['draft-workflow'].hidden;}
assert(draw());
e.dirty=true;assert(!draw());e.dirty=false;v.revision='b';assert(!draw());
v.revision='a';assert(!draw());now=2999;assert(!draw());now=3000;assert(draw());
e.dirty=true;assert(!draw());e.dirty=false;assert(!draw());now=4000;e.dirty=true;assert(!draw());now=9000;assert(!draw());
e={loaded:false,reconcile:true};assert(!draw());
console.log('PASS workflow visibility: initial, dirty, unapplied, 3 seconds, polling and new action');
