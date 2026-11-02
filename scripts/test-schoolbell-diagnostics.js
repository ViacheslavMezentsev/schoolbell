'use strict';
const assert=require('assert'),fs=require('fs'),vm=require('vm'),path=require('path');
const file=path.join(__dirname,'../ui/root/www/schoolbell-test/diagnostics.js'),diagnose=require(file);
const cases=[
 [{blocked:true},'session-login'],[{pending:true},'tab-sound'],[{},'tab-feedback'],[{uncertain:true},'tab-feedback'],
 [{value:{state:'running'}},'tab-preview'],[{value:{state:'playing'}},'tab-preview'],[{value:{state:'disabled',revision:'r'}},'tab-sound'],
 [{value:{state:'disabled'}},'tab-sound'],[{value:{state:'muted'}},'tab-sound'],[{value:{state:'recovery_required'}},'tab-media'],
 [{value:{state:'executor_error'}},'tab-journal'],[{value:{state:'clock_untrusted',clock_trust:{enforced:true,state:'review_required',reason:'observation_gap'}}},'clock-check-settings']
];
for(const [s,target] of cases)assert.equal(diagnose(s).target,target);
assert(diagnose({}).text.includes('не доказывает'));
assert(diagnose({value:{state:'disabled',clock_trust:{enforced:false,state:'unchecked'}}}).title.includes('не применён'));
const elements={},events={},clicks=[],emitted=[],draft={revision:'draft123',dirty:true};
function el(id){return elements[id]||(elements[id]={hidden:true,dataset:{},textContent:id==='duty-panel'?'Школьник 5.1.6':'',events:{},setAttribute(k,v){this[k]=v},addEventListener(k,fn){this.events[k]=fn},click(){clicks.push(id);this.events.click?.()},focus(){},scrollIntoView(){}});}
const window={schoolbellEditor:{snapshot:()=>draft},addEventListener:(k,fn)=>events[k]=fn,dispatchEvent:e=>{emitted.push(e.type);events[e.type]?.(e)}};
vm.runInNewContext(fs.readFileSync(file,'utf8'),{window,document:{getElementById:el},CustomEvent:function(type){this.type=type},fetch(){throw Error('diagnostic must not issue commands')}});
el('problem-open').click();assert(!el('problem-panel').hidden);
el('problem-refresh').click();assert.deepEqual(emitted,['schoolbell-diagnostic-refresh']);
window.dispatchEvent({type:'schoolbell-diagnostic-state',detail:{value:{state:'running',revision:'active123',generation:4,simulated:true,token:'must-not-leak'}}});
assert(el('problem-summary').textContent.includes('работает'));el('problem-action').click();assert(clicks.includes('tab-preview'));
const details=el('problem-details').textContent;assert(!details.includes('draft123')&&!details.includes('active123')&&details.includes('различаются'));assert(!details.includes('must-not-leak'));
window.dispatchEvent({type:'schoolbell-session-lost'});el('problem-action').click();assert.equal(clicks.at(-1),'session-login');
el('problem-journal').click();assert.equal(clicks.at(-1),'tab-journal');
el('problem-close').click();assert(el('problem-panel').hidden);assert(draft.dirty && draft.revision==='draft123');
assert(!clicks.some(x=>/automatic-enable|automatic-disable|trust-confirm|trust-policy|schedule-save/.test(x)));
console.log('PASS diagnostics: state causes, safe navigation/read event only, no command replay, draft preserved, technical data whitelist');
