(function(global){
'use strict';
function percent(a,b){
 if(!a||!b||!a.available||!b.available||a.boot!==b.boot)return null;
 var total=Number(b.total)-Number(a.total),idle=Number(b.idle)-Number(a.idle);
 if(!Number.isSafeInteger(Number(b.total))||!Number.isSafeInteger(Number(b.idle))||total<=0||idle<0||idle>total)return null;
 return Math.round((total-idle)*1000/total)/10;
}
function tone(p){return p===null?'unknown':p>90?'danger':p>75?'warning':'success';}
function uptime(seconds){if(!Number.isSafeInteger(seconds)||seconds<0)return null;var minutes=Math.floor(seconds/60);return Math.floor(minutes/1440)+' дн '+String(Math.floor(minutes/60)%24).padStart(2,'0')+' ч '+String(minutes%60).padStart(2,'0')+' мин';}
if(typeof module==='object'&&module.exports){module.exports={percent:percent,tone:tone,uptime:uptime};return;}
var wallClock=null;
var previous=null,value=null,at=0,bar=document.getElementById('cpu-line'),label=document.getElementById('cpu-value'),up=document.getElementById('device-uptime'),clock=document.getElementById('device-clock'),flash=document.getElementById('flash-line'),free=document.getElementById('flash-value');
global.schoolbellDisplayClock=function(wall){wallClock=typeof wall==='number'&&Number.isFinite(wall)?wall:null;draw();};
function draw(){var date=wallClock===null?null:new Date(wallClock);clock.textContent=global.schoolbellSessionBlocked||!date||!Number.isFinite(date.getTime())?'—:—':String(date.getUTCHours()).padStart(2,'0')+':'+String(date.getUTCMinutes()).padStart(2,'0');var stale=performance.now()-at>15000||global.schoolbellSessionBlocked,p=stale?null:value,u=stale?null:uptime(previous&&previous.uptime_seconds);up.textContent=u===null?'В работе · нет данных':(previous.simulated?'Демо · ':'')+u;if(flash){var disk=stale?null:previous&&previous.storage,valid=disk&&Number.isFinite(disk.total_kib)&&disk.total_kib>0&&Number.isFinite(disk.free_kib)&&disk.free_kib>=0&&disk.free_kib<=disk.total_kib,used=valid?100*(1-disk.free_kib/disk.total_kib):null;flash.dataset.tone=tone(used);flash.style.setProperty('--cpu-fill',(used===null?0:used)+'%');free.textContent=valid?(previous.simulated?'Демо Flash':'Flash')+' · свободно '+(disk.free_kib/1024).toFixed(2)+' МиБ ('+(100-used).toFixed(0)+'%)':'Flash · нет данных';if(used===null)flash.removeAttribute('aria-valuenow');else flash.setAttribute('aria-valuenow',used);}bar.dataset.tone=tone(p);bar.style.setProperty('--cpu-fill',(p===null?0:p)+'%');label.textContent=p===null?'CPU · нет измерения':'CPU · '+p.toFixed(1)+'%';if(p===null)bar.removeAttribute('aria-valuenow');else bar.setAttribute('aria-valuenow',p);}
global.addEventListener('schoolbell-system-metrics',function(e){value=percent(previous,e.detail);previous=e.detail;at=performance.now();draw();});
draw();setInterval(draw,1000);
})(typeof window==='object'?window:globalThis);
