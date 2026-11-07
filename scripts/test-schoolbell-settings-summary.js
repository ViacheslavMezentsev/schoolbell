const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('ui/root/www/schoolbell-test/dashboard.js','utf8');
const nodes={};
function el(id){return nodes[id]||(nodes[id]={textContent:'',disabled:false,selectedIndex:0,options:[{textContent:'32 КиБ'}],addEventListener(){}});}
el('session-duration').options=[{textContent:'30 минут'}];
el('device-clock').textContent='Вс 08.11.2026 · 00:22';
el('router-zone').textContent='Asia/Yekaterinburg · UTC+05:00 · получено 5 с назад';
el('audio-volume').textContent='50 %';
el('journal-limit-save').disabled=true;
let draft={mode:'annual',active_plan:'school',plans:[{id:'school',name:'Учебный 2026–2027'}],schedules:[],pre_minutes:2},dirty=false,draw;
const window={addEventListener(){},schoolbellEditor:{exportSnapshot:()=>({draft,dirty})}};
vm.runInNewContext(source.slice(source.lastIndexOf('(function(){')),{window,document:{getElementById:el},setInterval:f=>draw=f});
assert(el('summary-bells').textContent.includes('Учебный 2026–2027'));
assert(el('summary-bells').textContent.includes('50 %'));
assert(!el('summary-time').textContent.includes('получено'));
assert(el('summary-interface').textContent.includes('30 минут'));
dirty=true;el('journal-limit-save').disabled=false;draw();
assert(el('summary-bells').textContent.includes('несохранённые'));
assert(el('summary-interface').textContent.includes('не применено'));
window.schoolbellSessionBlocked=true;draw();
assert(el('summary-bells').textContent.includes('Войдите'));
console.log('PASS settings summaries: loaded data, pending changes and session loss');

const template=fs.readFileSync('ui/root/usr/lib/lua/luci/view/schoolbell_test.htm','utf8');
const ids=Array.from(template.matchAll(/\bid="([^"]+)"/g),m=>m[1]);
assert.equal(new Set(ids).size,ids.length,'Template IDs must be unique');
for(const id of ['summary-interface','summary-time','summary-bells']){
 assert(template.indexOf('id="'+id+'"')>template.indexOf('id="panel-sound"'));
}
console.log('PASS settings summary IDs: unique and located in Settings');

const css=fs.readFileSync('ui/root/www/schoolbell-test/style.css','utf8');
assert(css.includes('.settings-summary{display:list-item;list-style:disclosure-closed inside}'));
assert(!css.includes(".settings-summary:before"));
