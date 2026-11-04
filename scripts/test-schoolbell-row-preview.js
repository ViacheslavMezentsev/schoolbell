const fs=require('fs'),vm=require('vm'),assert=require('assert');
function fixture(demo=false){
 const nodes={};function node(){return {dataset:{},events:{},addEventListener(k,f){this.events[k]=f},pause(){},load(){},removeAttribute(){},play(){this.plays=(this.plays||0)+1;return Promise.resolve()}};}
 ['schedule-editor','row-preview-audio','row-preview-status','router-form'].forEach(id=>nodes[id]=node());nodes['schedule-editor'].dataset={load:demo?'demo-api/load':'load',sample:demo?'assets/test.mp3':'sample',token:'token'};nodes['router-form'].action='play';
 const x={nodes,posts:[],window:{addEventListener(){},confirm(){return true}}};
 x.window.schoolbellSpeakerCommand=send=>send(false);
 const fetch=async(url,opts)=>{x.posts.push({url,body:Object.fromEntries(opts.body)});if(x.fail)throw Error('lost');return {ok:true,json:async()=>({state:x.state||'completed'})}};
 vm.runInNewContext(fs.readFileSync('ui/root/www/schoolbell-test/row-preview.js','utf8'),{window:x.window,document:{getElementById:id=>nodes[id]},fetch,URLSearchParams,AbortController,setTimeout,clearTimeout});return x;
}
(async()=>{let x=fixture();await x.window.schoolbellRowPreview('user8',false);assert.equal(x.nodes['row-preview-audio'].src,'sample?id=user8');assert.equal(x.posts.length,0);
 await x.window.schoolbellRowPreview('user3',true);assert.deepEqual(x.posts[0],{url:'play',body:{token:'token',id:'user3'}});
 const mediaStatus={textContent:''};await x.window.schoolbellRowPreview('user3',true,mediaStatus);assert.equal(mediaStatus.textContent,'Мелодия завершена.');x.posts.pop();
 x.window.schoolbellSessionBlocked=true;await x.window.schoolbellRowPreview('test',true);assert.equal(x.posts.length,1);
 x=fixture(true);await x.window.schoolbellRowPreview('4',false);assert.equal(x.nodes['row-preview-audio'].src,'assets/4.mp3');await x.window.schoolbellRowPreview('4',true);assert.equal(x.posts.length,0);
 x=fixture();x.fail=true;await x.window.schoolbellRowPreview('test',true);assert.equal(x.posts.length,1);assert(x.nodes['row-preview-status'].textContent.includes('мог начаться'));await x.window.schoolbellRowPreview('../evil',true);assert.equal(x.posts.length,1);
 console.log('PASS row preview: selected ID, browser/device separation, demo/session guard, no retry after lost response');})().catch(e=>{console.error(e);process.exit(1)});
