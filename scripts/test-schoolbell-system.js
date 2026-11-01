const fs=require('fs'),vm=require('vm'),assert=require('assert');
function fixture(demo=false){
 class E{constructor(){this.events={};this.dataset={};this.disabled=false;this.hidden=false;this.textContent='';}addEventListener(k,f){this.events[k]=f;}click(){if(!this.disabled)return this.events.click?.();}}
 const ids=['system-settings','schedule-editor','system-reboot','system-reset','system-review','system-confirm','system-cancel','system-result','system-review-text','system-reload'];const elements=Object.fromEntries(ids.map(k=>[k,new E()]));const get=k=>{assert(elements[k],k);return elements[k];};
 get('system-settings').dataset.system=demo?'./demo-api/system':'system';get('schedule-editor').dataset.token='token';
 const x={get,posts:[],now:0,locks:0,unlocks:0,resets:0,reloads:0,fail:false};const events={},intervals=[];
 const context={document:{getElementById:get},window:{addEventListener:(k,f)=>events[k]=f,location:{reload:()=>x.reloads++},schoolbellEditor:{systemLock:()=>{x.locks++;return true;},unlock:()=>x.unlocks++,systemResetComplete:()=>x.resets++}},performance:{now:()=>x.now},crypto:{getRandomValues:a=>a},Uint8Array,Array,URLSearchParams,AbortController,setTimeout:()=>1,clearTimeout(){},setInterval:f=>intervals.push(f),localStorage:{removeItem(){}},fetch:async(url,opts)=>{assert(!demo);assert(opts.method==='POST');const q=Object.fromEntries(opts.body);assert(q.token==='token');x.posts.push(q);if(x.fail&&q.action!=='system_prepare')throw Error('lost');return {ok:true,json:async()=>q.action==='system_prepare'?{ok:true,challenge:q.operation}:{ok:true,state:q.action==='system_reset'?'reset':'reboot_requested'}};}};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/system.js','utf8'),context);x.tick=()=>intervals.forEach(f=>f());x.lost=()=>events['schoolbell-session-lost']();return x;
}
(async()=>{
 let x=fixture();assert(x.posts.length===0);await x.get('system-reset').click();assert(x.posts.length===1&&x.posts[0].action==='system_prepare');x.get('system-cancel').click();assert(x.posts.length===1&&x.get('system-review').hidden);
 await x.get('system-reset').click();await x.get('system-confirm').click();assert(x.resets===1&&x.locks===1&&x.posts.at(-1).action==='system_reset');assert(x.get('system-reload').hidden===false);x.get('system-reload').click();assert(x.reloads===1);
 x=fixture();await x.get('system-reboot').click();await x.get('system-confirm').click();assert(x.posts.at(-1).action==='system_reboot'&&x.resets===0&&x.unlocks===1);
 x=fixture();await x.get('system-reset').click();x.now=26000;x.tick();assert(x.get('system-confirm').disabled);assert(x.posts.length===1);
 x=fixture();await x.get('system-reset').click();x.fail=true;await x.get('system-confirm').click();assert(x.posts.length===2&&x.resets===0&&x.unlocks===1);assert(x.get('system-result').textContent.includes('не подтверждено'));
 x=fixture();await x.get('system-reboot').click();x.lost();assert(x.get('system-reboot').disabled&&x.get('system-review').hidden);
 x=fixture(true);assert(x.get('system-reset').disabled&&x.get('system-reboot').disabled&&x.posts.length===0);
 console.log('PASS System UI: prepare without effects, cancel, explicit confirm, expiry, unknown response without replay, session loss, editor reset, demo isolation');
})().catch(e=>{console.error(e);process.exitCode=1;});
