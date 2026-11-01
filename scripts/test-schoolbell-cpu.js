const assert=require('node:assert/strict');const {percent,tone,uptime}=require('../ui/root/www/schoolbell-test/cpu.js');
const a={available:true,boot:'a',total:'1000',idle:'500'};const b={available:true,boot:'a',total:'1200',idle:'550'};
assert.equal(percent(a,b),75);assert.equal(tone(75),'success');assert.equal(tone(75.1),'warning');assert.equal(tone(90),'warning');assert.equal(tone(90.1),'danger');assert.equal(tone(null),'unknown');
assert.equal(percent(null,b),null);assert.equal(percent(a,{...b,boot:'b'}),null);assert.equal(percent(a,a),null);assert.equal(percent(a,{...b,idle:'900'}),null);assert.equal(percent(b,a),null);
console.log('PASS CPU delta, boot change, invalid counters and exact 75/90 thresholds');

const fs=require('node:fs'),vm=require('node:vm');let now=0,tick,listener;const attrs={};const bar={dataset:{},style:{setProperty(k,v){attrs[k]=v;}},setAttribute(k,v){attrs[k]=v;},removeAttribute(k){delete attrs[k];}},label={},up={},clock={},flash={dataset:{},style:{setProperty(){}},setAttribute(){},removeAttribute(){}},free={};const win={addEventListener(n,f){listener=f;}};
vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/cpu.js','utf8'),{window:win,document:{getElementById:id=>id==='flash-line'?flash:id==='flash-value'?free:id==='cpu-line'?bar:id==='device-uptime'?up:id==='device-clock'?clock:label},performance:{now:()=>now},setInterval:f=>{tick=f;}});
assert.equal(bar.dataset.tone,'unknown');listener({detail:a});assert.equal(bar.dataset.tone,'unknown');listener({detail:b});assert.equal(bar.dataset.tone,'success');assert.equal(attrs['aria-valuenow'],75);now=15001;tick();assert.equal(bar.dataset.tone,'unknown');assert.equal(attrs['aria-valuenow'],undefined);listener({detail:{...b,total:'1300',idle:'555'}});assert.equal(bar.dataset.tone,'danger');win.schoolbellSessionBlocked=true;tick();assert.equal(bar.dataset.tone,'unknown');
console.log('PASS CPU UI: first sample, stale age, invalid state and logout cannot show false zero');

assert.equal(uptime(10*86400+6*3600+10*60),'10 дн 06 ч 10 мин');assert.equal(uptime(59),'0 дн 00 ч 00 мин');assert.equal(uptime(86400),'1 дн 00 ч 00 мин');for(const v of [null,undefined,-1,NaN,Infinity,1.5,'60'])assert.equal(uptime(v),null);
win.schoolbellSessionBlocked=false;now=0;listener({detail:{...b,uptime_seconds:86460}});assert.equal(up.textContent,'1 дн 00 ч 01 мин');listener({detail:{available:false,uptime_seconds:60,simulated:true}});assert.equal(up.textContent,'Демо · 0 дн 00 ч 01 мин');now=15001;tick();assert.equal(up.textContent,'В работе · нет данных');now=0;listener({detail:{...a,uptime_seconds:0,boot:'new'}});assert.equal(up.textContent,'0 дн 00 ч 00 мин');win.schoolbellSessionBlocked=true;tick();assert.equal(up.textContent,'В работе · нет данных');console.log('PASS uptime: minute/day boundaries, invalid/stale/logout, reboot and explicit demo age');

win.schoolbellSessionBlocked=false;
win.schoolbellDisplayClock(Date.UTC(2026,9,30,20,54,59));assert.equal(clock.textContent,'Пт 30.10.2026 · 20:54');
win.schoolbellDisplayClock(Date.UTC(2026,9,31,0,0,0));assert.equal(clock.textContent,'Сб 31.10.2026 · 00:00');
win.schoolbellDisplayClock(Date.UTC(2027,0,1,0,0));assert.equal(clock.textContent,'Пт 01.01.2027 · 00:00');
win.schoolbellDisplayClock(Date.UTC(2026,10,1,16,24));assert.equal(clock.textContent,'Вс 01.11.2026 · 16:24');
for(const v of [null,undefined,NaN,Infinity,'20:54']){win.schoolbellDisplayClock(v);assert.equal(clock.textContent,'—:—');}
win.schoolbellDisplayClock(Date.UTC(2026,9,30,20,54));win.schoolbellSessionBlocked=true;tick();assert.equal(clock.textContent,'—:—');
console.log('PASS header clock: device wall time, 24h/midnight, unavailable and blocked session');

win.schoolbellSessionBlocked=false;now=0;
listener({detail:{...b,storage:{total_kib:4096,free_kib:1024}}});assert.equal(flash.dataset.tone,'success');assert.match(free.textContent,/1.00 МиБ \(25 %\)/);
listener({detail:{...b,storage:{total_kib:4096,free_kib:400}}});assert.equal(flash.dataset.tone,'danger');
listener({detail:{...b,storage:{total_kib:4096,free_kib:800}}});assert.equal(flash.dataset.tone,'warning');
listener({detail:{...b,storage:{total_kib:0,free_kib:0}}});assert.equal(flash.dataset.tone,'unknown');
listener({detail:{...b,storage:{total_kib:4096,free_kib:5000}}});assert.equal(free.textContent,'Flash · нет данных');
console.log('PASS Flash: free MiB/percent, thresholds, invalid filesystem data');
