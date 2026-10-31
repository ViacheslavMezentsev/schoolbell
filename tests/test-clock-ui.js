const fs=require('fs'),vm=require('vm'),assert=require('assert');
const nodes=new Map(),listeners={};let calls=[],fail=false,at=0,serial=0,responses=null;
function node(id){if(!nodes.has(id))nodes.set(id,{textContent:'',hidden:false,checked:false,disabled:false,parentElement:{hidden:false},dataset:{token:'csrf',trust:'/clock'},events:{},addEventListener(k,fn){this.events[k]=fn;}});return nodes.get(id);}
const ctx={document:{getElementById:node},window:{addEventListener:(n,fn)=>listeners[n]=fn,confirm:()=>true},Uint8Array,Array,String,Object,Date,Error,URLSearchParams,AbortController,performance:{now:()=>at},crypto:{getRandomValues:b=>b.fill(++serial)},setInterval(){},setTimeout(fn,delay){if(delay<=500)queueMicrotask(()=>{at+=delay;fn();});return 1;},clearTimeout(){},fetch:async(url,opts)=>{calls.push({url,opts});if(fail)throw Error('network interrupted');if(responses){let v=responses.length>1?responses.shift():responses[0];return {ok:true,json:async()=>v};}let body=opts.body;let action=body&&body.get('action');return {ok:true,json:async()=>action==='prepare'?{ok:true,challenge:'challenge',utc:1790000000,zone:'UTC',rollback:true}:{ok:true}};}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/clock-trust.js','utf8'),ctx);
(async()=>{
 listeners['schoolbell-clock-state']({detail:{enforced:true,state:'unconfirmed'}});
 await node('trust-prepare').events.click();assert(!node('trust-review').hidden && !node('trust-confirm').disabled);
 node('trust-rollback').checked=true;await node('trust-confirm').events.click();assert(calls[1].opts.body.get('ack')==='true');assert(calls[1].opts.body.get('token')==='csrf');assert(node('trust-review').hidden);
 await node('trust-policy').events.click();assert(calls[2].opts.body.get('enforced')==='false');assert(!calls.some(c=>c.opts.body.get('action')==='enable'));
 fail=true;await node('trust-prepare').events.click();assert(!node('trust-prepare').disabled && node('trust-result').textContent.includes('network'));
 fail=false;await node('trust-prepare').events.click();at=15000;let count=calls.length;await node('trust-confirm').events.click();assert(calls.length===count);
 for(const tail of [[{ok:true,done:true}],[{ok:false,code:'busy'},{ok:true,done:true}],[{ok:true,pending:true,waiting:'writer'},{ok:true,done:true}]]){
 calls=[];responses=[{ok:true,pending:true},...tail];let result=await ctx.window.schoolbellClockCommand({action:'policy',enforced:'false'});assert(result.done);assert(calls.filter(v=>v.opts.method==='POST').length===1);assert(calls.slice(1).every(v=>!v.opts.method));
 }
 calls=[];responses=[{ok:true,pending:true},{ok:false,code:'busy'}];await assert.rejects(()=>ctx.window.schoolbellClockCommand({action:'prepare'}),/отведённое время/);assert(calls.filter(v=>v.opts.method==='POST').length===1 && calls.length<=37);
 calls=[];responses=[{ok:false,code:'busy'}];await assert.rejects(()=>ctx.window.schoolbellClockCommand({action:'prepare'}),/не принята/);assert(calls.length===1);
 calls=[];responses=[{ok:true,pending:true},{ok:false,code:'mailbox_storage'}];await assert.rejects(()=>ctx.window.schoolbellClockCommand({action:'prepare'}),/хранилища/);assert(calls.length===2);
 console.log('PASS bounded busy/pending GET, one POST, exhaustion, rejected submission and real storage error');
 console.log('PASS clock UI: explicit confirmation, rollback checkbox, CSRF, bypass never enables, network recovery, expiry');
})().catch(e=>{console.error(e);process.exitCode=1;});
