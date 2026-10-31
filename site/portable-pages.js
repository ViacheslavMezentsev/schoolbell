/* Pages-only .sbp I/O. No fetch, persistence, activation or device API. */
(function(root){
 'use strict';
 function create(C,E,P,crypto,config){
  const need=(v,c)=>{if(!v)throw Error(c);};
  const hex=b=>Array.from(new Uint8Array(b),x=>x.toString(16).padStart(2,'0')).join('');
  function hashFactory(){let parts=[],size=0;return {update(b){size+=b.length;need(size<=16384,'size');parts.push(b.slice());},async finish(){const b=new Uint8Array(size);let at=0;for(const p of parts){b.set(p,at);at+=p.length;}parts=[];return hex(await crypto.subtle.digest('SHA-256',b));}};}
  function zone(name){need(Object.prototype.hasOwnProperty.call(config.zones,name),'timezone');return {name,posix:config.zones[name]};}
  function snapshot(s){need(s&&s.draft,'unavailable');need(!s.busy&&!s.reconcile&&!s.formPending,'pending');return JSON.parse(JSON.stringify(s));}
  async function exportFile(s,selected,name){s=snapshot(s);const chunks=[];
   await E.encode({draft:s.draft,selected,timezone:zone(name),media:config.media,exporter:{name:'schoolbell-pages',version:config.version}},()=>{throw Error('unsupported_media');},hashFactory,b=>{chunks.push(b.slice());});
   return new Blob(chunks,{type:'application/octet-stream'});
  }
  async function readFile(file){
   need(file&&Number.isSafeInteger(file.size)&&file.size>=82&&file.size<=C.maximum,'size');
   const header=new Uint8Array(await file.slice(0,82).arrayBuffer()),text=new TextDecoder().decode(header);
   need(/^SBPLAN1\n[0-9]{8}\n[0-9a-f]{64}\n$/.test(text),'format');
   const n=Number(text.slice(8,16));need(n>=1&&n<=16384,'size');need(file.size>=82+n,'truncated');
   const raw=new Uint8Array(await file.slice(82,82+n).arrayBuffer()),h=hashFactory();h.update(raw);need(await h.finish()===text.slice(17,81),'checksum');
   const parsed=C.manifest(raw);need(!parsed.manifest.media.some(m=>m.source==='user'),'unsupported_media');
   need(file.size===parsed.bytes,'size');zone(parsed.manifest.timezone.name);need(zone(parsed.manifest.timezone.name).posix===parsed.manifest.timezone.posix,'timezone');
   let offset=0;const decoded=await C.decode(async()=>{if(offset===file.size)return null;const end=Math.min(offset+C.chunk,file.size);const b=new Uint8Array(await file.slice(offset,end).arrayBuffer());offset=end;return b;},hashFactory);
   return {manifest:raw,calendar:decoded.calendar,summary:C.parseJSON(decoded.calendar,12288),timezone:decoded.manifest.timezone};
  }
  function preview(file,s,name,names,enabled){s=snapshot(s);const id=new Uint8Array(16);crypto.getRandomValues(id);
   return P.preview(file.manifest,file.calendar,{draft:s.draft,timezone:zone(name),media:config.media.map(({id,size_bytes,sha256})=>({id,size_bytes,sha256})),operation_id:hex(id),automatic_enabled:enabled,dirty:!!s.dirty,target:'pages',names});
  }
  return {exportFile,readFile,preview};
 }
 if(typeof module!=='undefined'&&module.exports)module.exports={create};else root.SchoolbellPortablePages={create};
})(typeof globalThis!=='undefined'?globalThis:this);
