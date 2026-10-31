const fs=require('fs'),assert=require('assert'),P=require('./preview.js');
const dir=process.argv[2],index=JSON.parse(fs.readFileSync(dir+'/index.json'));
for(const name of index){const ctx=JSON.parse(fs.readFileSync(dir+'/'+name+'.context')),before=JSON.stringify(ctx);
 const result=P.preview(fs.readFileSync(dir+'/'+name+'.manifest'),fs.readFileSync(dir+'/'+name+'.calendar'),ctx);
 assert.strictEqual(JSON.stringify(ctx),before,'mutated '+name);assert.strictEqual(result.admitted,false);assert(result.ok||!result.candidate);
 console.log(JSON.stringify({name,result}));}
