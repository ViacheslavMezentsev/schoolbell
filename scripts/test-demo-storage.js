const fs=require('fs'),vm=require('vm'),assert=require('assert');
const NEW='schoolbell-public-demo-v1',OLD='openwrt-schoolbell-public-demo-v1';
function boot(storage=new Map(),opts={}){
 const elements=new Map();let reloads=0,confirms=0;
 const document={getElementById(id){if(!elements.has(id))elements.set(id,{hidden:true,textContent:'',handlers:{},addEventListener(n,fn){this.handlers[n]=fn;}});return elements.get(id);}};
 const c={window:{},document,performance:{now:()=>0},TextEncoder,Intl,Date,Math,Number,JSON,Array,String,URL,URLSearchParams,
  Response:class{constructor(body){this.body=body;}json(){return Promise.resolve(JSON.parse(this.body));}},
  location:{href:'https://example.test/schoolbell/',origin:'https://example.test',reload(){reloads++;}},
  confirm(){confirms++;return opts.confirm!==false;},
  localStorage:{getItem(k){if(opts.readFails)throw Error('denied');return storage.has(k)?storage.get(k):null;},setItem(k,v){if(opts.writeFails)throw Error('quota');storage.set(k,v);}}};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/ranges.js','utf8'),c);
 vm.runInNewContext(fs.readFileSync('site/demo.js','utf8'),c);
 return {c,storage,e:id=>document.getElementById(id),click:id=>document.getElementById(id).handlers.click(),reloads:()=>reloads,confirms:()=>confirms,api:async()=> (await c.window.fetch('./demo-api/load')).json()};
}
(async()=>{
 let b=boot();const seed=(await b.api()).data;
 const old=JSON.stringify({format:1,revision:7,zone:'UTC',log:[],seq:0,autoEnabled:true,data:seed});
 const saved=new Map([[OLD,old]]);b=boot(saved);assert(!b.e('demo-migrate').hidden);assert(!saved.has(NEW));
 b.click('demo-migrate');assert.equal(b.reloads(),1);assert.equal(saved.get(OLD),old);
 const copied=JSON.parse(saved.get(NEW));assert.equal(copied.autoEnabled,false);assert.deepStrictEqual(copied.data,seed);assert.equal(copied.revision,7);
 b=boot(saved);assert(b.e('demo-migrate').hidden);b.click('demo-migrate');assert.equal(b.reloads(),0);assert.equal(saved.get(OLD),old);
 b.click('demo-reset');assert.equal(saved.get(OLD),old);assert.equal(JSON.parse(saved.get(NEW)).revision,1);
 b=boot(new Map([[OLD,old]]),{confirm:false});b.click('demo-migrate');assert(!b.storage.has(NEW));
 b=boot(new Map([[OLD,old]]),{writeFails:true});b.click('demo-migrate');assert.equal(b.reloads(),0);assert(!b.storage.has(NEW));assert.equal(b.storage.get(OLD),old);
 b=boot(new Map([[OLD,'broken']]));assert(b.e('demo-migrate').hidden);assert.equal(b.storage.get(OLD),'broken');
 b=boot(new Map([[OLD,old]]));b.c.window.schoolbellEditor={portableSnapshot:()=>({dirty:true})};b.click('demo-migrate');assert.equal(b.confirms(),0);assert(!b.storage.has(NEW));
 b=boot(new Map([[OLD,old]]));b.storage.set(NEW,'another tab');b.click('demo-migrate');assert.equal(b.storage.get(NEW),'another tab');assert.equal(b.reloads(),0);
 b=boot(new Map([[OLD,old],[NEW,'corrupt new data']]));assert(b.e('demo-migrate').hidden);assert.equal(b.storage.get(NEW),'corrupt new data');
 b=boot(new Map(),{readFails:true});assert(b.e('demo-migrate').hidden);assert((await b.api()).ok);
 console.log('PASS demo storage: explicit copy, cancel, old key retained, new/dirty data protected, corrupt data and denied/quota failures, reset isolation, simulated auto off');
})().catch(e=>{console.error(e);process.exitCode=1;});
