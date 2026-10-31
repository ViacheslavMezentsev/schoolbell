const fs=require('fs'),crypto=require('crypto'),assert=require('assert');
const codec=require('./codec.js');
const dir=process.argv[2],cases=JSON.parse(fs.readFileSync(dir+'/index.json'));
const factory=()=>{const h=crypto.createHash('sha256');return{update:c=>{h.update(c);},finish:()=>h.digest('hex')};};
function source(bytes,n){let p=0;return async()=>p>=bytes.length?null:bytes.subarray(p,(p=Math.min(bytes.length,p+n)));}
(async()=>{let count=0;
 for(const c of cases){const bytes=fs.readFileSync(dir+'/'+c.file);for(const n of c.chunks){
   let result,error;const files=new Map();
   try{result=await codec.decode(source(bytes,n),factory,(name,b)=>{if(!files.has(name))files.set(name,[]);files.get(name).push(b);});}catch(e){error=e;}
   assert.strictEqual(!error,c.ok,c.name+'/'+n+' '+error);
   if(result){assert.strictEqual(result.admitted,false);assert.strictEqual(result.bytes,c.size);const encoded=[];
     await codec.encode(fs.readFileSync(dir+'/'+c.file+'.manifest'),name=>source(Buffer.concat(files.get(name)),n),factory,b=>{assert(b.length<=16384);encoded.push(b);});
     assert.deepStrictEqual(Buffer.concat(encoded),bytes,c.name+' roundtrip');
   }count++;
 }}
 const valid=fs.readFileSync(dir+'/golden.sbp'),raw=fs.readFileSync(dir+'/golden.sbp.manifest');
 await assert.rejects(()=>codec.decode(async()=>new Uint8Array(0),factory));
 await assert.rejects(()=>codec.decode(async()=>new Uint8Array(16385),factory));
 await assert.rejects(()=>codec.decode(async()=>{throw Error('read failed');},factory));
 await assert.rejects(()=>codec.decode(source(valid,7),factory,()=>false));
 await assert.rejects(()=>codec.decode(source(valid,7),()=>({update:()=>false})));
 await assert.rejects(()=>codec.encode(raw,()=>async()=>null,factory,()=>true));
 await assert.rejects(()=>codec.encode(raw,()=>{throw Error('must not open');},factory,()=>false));
 console.log('[sbp JS] '+count+' shared stream cases + callback failures passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
