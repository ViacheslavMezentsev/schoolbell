const fs=require('fs'),assert=require('assert'),crypto=require('crypto');
const E=require('./export.js'),D=require('./codec.js'),P=require('./preview.js');
const dir=process.argv[2],index=JSON.parse(fs.readFileSync(dir+'/index.json'));
const factory=()=>{const h=crypto.createHash('sha256');return {update:c=>{h.update(c);},finish:()=>h.digest('hex')};};
(async()=>{for(const v of index){const input=JSON.parse(fs.readFileSync(dir+'/'+v.name+'.json')),before=JSON.stringify(input);let emitted=0,opened=[];
 const output=[];let error=null;
 try{const bytes=await E.encode(input,(slot,meta)=>{opened.push(slot);if(v.fault==='open')throw Error('open');const data=fs.readFileSync(dir+'/'+v.name+'.'+slot);let i=0;return ()=>{if(v.fault==='read')throw Error('read');if(i===data.length)return null;const c=data.subarray(i,i+16384);i+=c.length;return c;};},factory,c=>{emitted++;if(v.fault==='emit')return false;assert(c.length<=16384);output.push(c);});
  const archive=Buffer.concat(output);assert.strictEqual(bytes,archive.length);fs.writeFileSync(dir+'/'+v.name+'.js.sbp',archive);
  let i=0;const parsed=await D.decode(()=>{if(i===archive.length)return null;const c=archive.subarray(i,i+16384);i+=c.length;return c;},factory);
  const manifestLength=Number(archive.subarray(8,16).toString());
  const ctx={draft:{schedules:[],plans:[],pre_minutes:2,pre_media:'test'},timezone:input.timezone,media:input.media.filter(x=>!x.id.startsWith('user')).map(({id,size_bytes,sha256})=>({id,size_bytes,sha256})),operation_id:'0123456789abcdef0123456789abcdef',automatic_enabled:false,dirty:false,target:'device',names:{plans:{},schedules:{}}};
  const preview=P.preview(archive.subarray(82,82+manifestLength),parsed.calendar,ctx);assert(preview.ok,JSON.stringify(preview));
 }catch(e){error=String(e);}
 assert.strictEqual(JSON.stringify(input),before,'mutated input');assert.strictEqual(error===null,v.ok,v.name+': '+error);
 if(v.early)assert.strictEqual(emitted,0,v.name+' emitted before validation');
 console.log(JSON.stringify({name:v.name,ok:error===null,opened}));
}})().catch(e=>{console.error(e);process.exit(1);});
