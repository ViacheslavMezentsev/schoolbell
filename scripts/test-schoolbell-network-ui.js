const fs=require('fs'),vm=require('vm'),assert=require('assert');
const els={};for(const id of ['schedule-editor','network-enabled','network-host','network-save','network-result','network-internet','network-ntp'])els[id]={dataset:{network:'/network',token:'test'},addEventListener(type,fn){this[type]=fn;},value:'',checked:false};
const events={},window={addEventListener(k,f){events[k]=f;}},calls=[];
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/network.js','utf8'),{window,document:{getElementById:id=>els[id]},setTimeout,clearTimeout,URLSearchParams,AbortController,fetch:async(url,opts)=>{calls.push(opts);return {ok:true,json:async()=>({ok:true,network:{config:{enabled:false,host:'time.local'},internet:{state:'disabled'},ntp:{state:'waiting'}}})};}});
(async()=>{
 window.schoolbellNetworkRender({config:{enabled:true,host:'1.1.1.1'},internet:{state:'available',age_seconds:2,host:'1.1.1.1'},ntp:{state:'waiting'}});
 assert.equal(calls.length,0);assert(els['network-internet'].textContent.includes('доступен'));assert(els['network-ntp'].textContent.includes('ожидание'));assert(els['network-save'].disabled);
 els['network-host'].value='bad host';els['network-host'].input();assert(els['network-save'].disabled);
 els['network-host'].value='time.local';els['network-enabled'].checked=false;els['network-host'].input();assert(!els['network-save'].disabled);
 window.schoolbellNetworkRender({config:{enabled:true,host:'1.1.1.1'},internet:{state:'unconfirmed'},ntp:{state:'synced'}});assert.equal(els['network-host'].value,'time.local');
 await els['network-save'].click();assert.equal(calls.length,1);assert.equal(calls[0].body.get('host'),'time.local');assert(els['network-save'].disabled);
 window.schoolbellNetworkRender({config:{enabled:false,host:'time.local'},internet:{state:'demo'},ntp:{state:'demo'}});assert(els['network-internet'].textContent.includes('нет данных'));assert.equal(calls.length,1);
 window.schoolbellSessionBlocked=true;events['schoolbell-session-lost']();assert(els['network-save'].disabled);assert(els['network-internet'].textContent.includes('нет данных'));
 console.log('network UI: cached render, independent states, validation, dirty form, save, demo and session loss PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
