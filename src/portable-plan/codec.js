/* Isolated SBPLAN1 codec. Byte streams and SHA adapters are injected.
 * Tentative output MUST be discarded on failure. Success is NOT import admission. */
'use strict';
(function(root) {
  const MAGIC = 'SBPLAN1\n', MAXIMUM = 2125906, CHUNK = 16384;
  const enc = new TextEncoder(), dec = new TextDecoder('utf-8', {fatal:true, ignoreBOM:true});
  function need(ok, code) { if (!ok) throw new Error(code); }
  // JSON.parse alone loses duplicate keys. Scan the bounded text first, including
  // escaped keys and surrogate pairs, then use the native parser for values.
  function json(raw, max) {
    need(raw instanceof Uint8Array && raw.length > 0 && raw.length <= max, 'size');
    let s; try { s = dec.decode(raw); } catch (_) { throw new Error('format'); }
    let p=0, nodes=0;
    function ws(){while(/[ \t\r\n]/.test(s[p] || '\0'))p++;}
    function str(){
      const start=p++; let escape=false;
      while(p<s.length){const ch=s[p++];if(ch==='"'&&!escape){
        let v;try{v=JSON.parse(s.slice(start,p));}catch(_){throw new Error('format');}
        for(let i=0;i<v.length;i++){const c=v.charCodeAt(i);if(c>=0xd800&&c<=0xdbff){const d=v.charCodeAt(++i);need(d>=0xdc00&&d<=0xdfff,'format');}else need(!(c>=0xdc00&&c<=0xdfff),'format');}
        return v;
      }if(ch==='\\'&&!escape)escape=true;else escape=false;}
      throw new Error('format');
    }
    function value(depth){
      need(++nodes<=4096,'format');ws();const c=s[p];
      if(c==='"'){str();return;}
      if(c==='{'||c==='['){need(depth<8,'format');p++;ws();const end=c==='{'?'}':']', keys=new Set();if(s[p]===end){p++;return;}
        for(;;){ws();if(c==='{'){need(s[p]==='"','format');const k=str();need(++nodes<=4096,'format');need(!keys.has(k),'format');keys.add(k);ws();need(s[p++]===':','format');}value(depth+1);ws();if(s[p]===end){p++;return;}need(s[p++ ]===',','format');}
      }
      const m=/^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/.exec(s.slice(p));need(m,'format');if(/^[0-9-]/.test(m[0]))need(Number.isFinite(Number(m[0]))&&Math.abs(Number(m[0]))<=9007199254740991,'format');p+=m[0].length;
    }
    value(0);ws();need(p===s.length,'format');try{return JSON.parse(s);}catch(_){throw new Error('format');}
  }
  function fields(v, keys){need(v!==null&&typeof v==='object'&&!Array.isArray(v),'format');need(Object.keys(v).length===keys.length&&keys.every(k=>Object.prototype.hasOwnProperty.call(v,k)),'format');}
  const ascii=(v,n)=>typeof v==='string'&&v.length>0&&v.length<=n&&/^[\x20-\x7e]+$/.test(v);
  const hex=v=>typeof v==='string'&&/^[0-9a-f]{64}$/.test(v);
  const integer=(v,a,b)=>Number.isInteger(v)&&v>=a&&v<=b;
  function manifest(raw){
    const m=json(raw,16384);fields(m,['format','exporter','timezone','files','media']);need(['schoolbell-plan/1','schoolbell-plan/2'].includes(m.format),'format');
    fields(m.exporter,['name','version']);need(['schoolbell-device','schoolbell-pages'].includes(m.exporter.name)&&ascii(m.exporter.version,32)&&/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/.test(m.exporter.version),'format');
    fields(m.timezone,['name','posix']);need(ascii(m.timezone.name,64)&&ascii(m.timezone.posix,256),'format');
    need(Array.isArray(m.files)&&m.files.length>=1&&(m.format!=='schoolbell-plan/1'||m.files.length<=9)&&Array.isArray(m.media)&&m.media.length>=1&&(m.format!=='schoolbell-plan/1'||m.media.length<=14),'format');
    const files=new Map();let total=82+raw.length,audio=0,prior='';
    m.files.forEach((f,i)=>{fields(f,['name','size_bytes','sha256']);need(integer(f.size_bytes,1,i===0?12288:524288),'size');need(hex(f.sha256),'format');
      if(i===0)need(f.name==='calendar.json','format');else{need(f.name==='media/'+f.sha256+'.mp3'&&f.sha256>prior,'format');prior=f.sha256;audio+=f.size_bytes;}
      need(!files.has(f.name),'format');files.set(f.name,f);total+=f.size_bytes;
    });need(audio<=2097152&&total<=MAXIMUM,'size');
    const ids=new Set(),bundled=new Set(),used=new Set();
    m.media.forEach(v=>{need(v!==null&&typeof v==='object','format');fields(v,['id','title','source','size_bytes','sha256',v.source==='bundled'?'bundled_id':'file']);
      need(typeof v.id==='string'&&/^[A-Za-z0-9_-]{1,64}$/.test(v.id)&&!ids.has(v.id),'format');ids.add(v.id);
      need(typeof v.title==='string'&&enc.encode(v.title).length>=1&&enc.encode(v.title).length<=96&&!/[\x00-\x1f\x7f]/.test(v.title)&&/[^ \t\r\n\v\f]/.test(v.title),'format');
      need(integer(v.size_bytes,1,524288),'size');need(hex(v.sha256),'format');
      if(v.source==='bundled'){need(['test','0','1','2','3','4'].includes(v.bundled_id)&&!bundled.has(v.bundled_id),'format');bundled.add(v.bundled_id);}
      else{need(v.source==='user'&&v.file==='media/'+v.sha256+'.mp3','format');const f=files.get(v.file);need(f&&f.size_bytes===v.size_bytes&&f.sha256===v.sha256,'dependency');used.add(v.file);}
    });m.files.slice(1).forEach(f=>need(used.has(f.name),'dependency'));
    return {manifest:m,bytes:total};
  }
  function reader(source){
    let buffer=new Uint8Array(0),ended=false,total=0;
    async function fill(){const c=await source();if(c===null){ended=true;return;}need(c instanceof Uint8Array&&c.length>0&&c.length<=CHUNK,'chunk');total+=c.length;need(total<=MAXIMUM,'size');const b=new Uint8Array(buffer.length+c.length);b.set(buffer);b.set(c,buffer.length);buffer=b;}
    return {async take(n){while(buffer.length<n&&!ended)await fill();need(buffer.length>=n,'truncated');const c=buffer.slice(0,n);buffer=buffer.slice(n);return c;},async eof(){need(buffer.length===0,'trailing');if(!ended)await fill();need(ended&&buffer.length===0,'trailing');return total;}};
  }
  const text=b=>String.fromCharCode(...b);
  async function digest(factory,raw){const h=factory();need(await h.update(raw)!==false,'io');return await h.finish();}
  async function decode(source,hashFactory,sink){
    const r=reader(source);need(text(await r.take(8))===MAGIC,'format');const line=text(await r.take(9));need(/^[0-9]{8}\n$/.test(line),'format');const n=Number(line);need(n>=1&&n<=16384,'size');const h=text(await r.take(65));need(h[64]==='\n'&&hex(h.slice(0,64)),'format');
    const raw=await r.take(n);need(await digest(hashFactory,raw)===h.slice(0,64),'checksum');const parsed=manifest(raw);let calendar;
    for(let i=0;i<parsed.manifest.files.length;i++){
      const f=parsed.manifest.files[i],hash=hashFactory();let left=f.size_bytes,offset=0;const meta=i===0?new Uint8Array(f.size_bytes):null;
      while(left>0){const c=await r.take(Math.min(left,CHUNK));left-=c.length;need(await hash.update(c)!==false,'io');if(meta){meta.set(c,offset);offset+=c.length;}if(sink)need(await sink(f.name,c)!==false,'io');}
      need(await hash.finish()===f.sha256,'checksum');if(meta){json(meta,12288);calendar=meta;}
    }
    need(await r.eof()===parsed.bytes,'size');return {...parsed,calendar,admitted:false};
  }
  async function encode(raw,sourceFor,hashFactory,emit){
    const parsed=manifest(raw);need(await emit(enc.encode(MAGIC+String(raw.length).padStart(8,'0')+'\n'+await digest(hashFactory,raw)+'\n'))!==false,'io');need(await emit(raw)!==false,'io');
    for(let i=0;i<parsed.manifest.files.length;i++){
      const f=parsed.manifest.files[i],r=reader(await sourceFor(f.name)),hash=hashFactory();let left=f.size_bytes,offset=0;const meta=i===0?new Uint8Array(f.size_bytes):null;
      while(left>0){const c=await r.take(Math.min(left,CHUNK));left-=c.length;need(await hash.update(c)!==false,'io');need(await emit(c)!==false,'io');if(meta){meta.set(c,offset);offset+=c.length;}}
      need(await r.eof()===f.size_bytes,'size');need(await hash.finish()===f.sha256,'checksum');if(meta)json(meta,12288);
    }return parsed.bytes;
  }
  const api=Object.freeze({manifest,encode,decode,parseJSON:json,maximum:MAXIMUM,chunk:CHUNK});
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.SchoolbellPlanCodec=api;
})(typeof globalThis!=='undefined'?globalThis:this);
