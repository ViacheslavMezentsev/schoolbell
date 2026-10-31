"""Independent wire generator; both codecs consume identical byte vectors.
Synthetic payloads test framing, not MP3 admission. No production files touched.
"""
import copy, hashlib, json, os, pathlib, shutil, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
def raw(v):return json.dumps(v,ensure_ascii=False,separators=(',',':')).encode()
def sha(b):return hashlib.sha256(b).hexdigest()
def frame(m,files):return b'SBPLAN1\n'+('%08d\n'%len(m)).encode()+sha(m).encode()+b'\n'+m+b''.join(files)
fixture=json.loads((HERE/'fixture.json').read_text());manifest=fixture['manifest'].encode();cal=fixture['calendar'].encode();base=json.loads(manifest)
gold=frame(manifest,[cal]);assert gold.hex()==fixture['archive_hex'] and sha(gold)==fixture['archive_sha256']
with tempfile.TemporaryDirectory(prefix='sbp-codec-') as tmp:
 d=pathlib.Path(tmp);cases=[]
 def add(name,m=None,files=None,ok=False,body=None,chunks=None):
  m=manifest if m is None else m;files=[cal] if files is None else files
  blob=frame(m,files) if body is None else body
  f=name+'.sbp';(d/f).write_bytes(blob)
  if ok:(d/(f+'.manifest')).write_bytes(m)
  cases.append(dict(name=name,file=f,ok=ok,size=len(blob),chunks=chunks or [1,7,16384]))
 add('golden',ok=True)
 add('json-spaces',b' \n'+manifest+b'\t',ok=True)
 for n in [0,1,7,8,16,17,81,82,82+len(manifest)-1,len(gold)-1]:add('cut-'+str(n),body=gold[:n])
 add('trailing',body=gold+b'x');add('crlf',body=gold.replace(b'SBPLAN1\n',b'SBPLAN1\r\n',1))
 add('zero-length',body=gold[:8]+b'00000000\n'+gold[17:])
 add('large-length',body=gold[:8]+b'00016385\n'+gold[17:])
 add('signed-length',body=gold[:8]+b'+0000001\n'+gold[17:])
 add('header-hash',body=gold[:17]+b'0'*64+gold[81:])
 add('uppercase-hash',body=gold[:17]+gold[17:81].upper()+gold[81:])
 add('payload-hash',body=gold[:-1]+b' ')
 add('duplicate-key',manifest.replace(b'"format":',b'"format":"x","format":',1))
 add('escaped-duplicate',manifest.replace(b'"format":',b'"for\\u006dat":"x","format":',1))
 add('bom',b'\xef\xbb\xbf'+manifest)
 add('invalid-utf8',manifest.replace('Синтетический'.encode(),b'\xff'))
 add('lone-surrogate',manifest.replace('Синтетический'.encode(),b'\ud800'))
 for name,change in [
  ('unknown',lambda m:m.update(extra=1)),('version',lambda m:m.update(format='schoolbell-plan/3')),
  ('null-exporter',lambda m:m.update(exporter=None)),('array-timezone',lambda m:m.update(timezone=[])),
  ('leading-zero',lambda m:m['exporter'].update(version='05.1.1')),
  ('path',lambda m:m['files'][0].update(name='../calendar.json')),
  ('zero-file',lambda m:m['files'][0].update(size_bytes=0)),
  ('large-calendar',lambda m:m['files'][0].update(size_bytes=12289)),
  ('fraction',lambda m:m['files'][0].update(size_bytes=3.5)),
  ('negative',lambda m:m['files'][0].update(size_bytes=-1)),
  ('hash-case',lambda m:m['files'][0].update(sha256=m['files'][0]['sha256'].upper())),
  ('missing-media',lambda m:m.update(media=[])),
  ('duplicate-media',lambda m:m['media'].append(copy.deepcopy(m['media'][0]))),
  ('unknown-source',lambda m:m['media'][0].update(source='remote')),
  ('bad-id',lambda m:m['media'][0].update(id='../bell')),
  ('blank-title',lambda m:m['media'][0].update(title='   ')),
  ('long-title',lambda m:m['media'][0].update(title='я'*49)),
  ('bad-bundled',lambda m:m['media'][0].update(bundled_id='6')),
 ]:
  m=copy.deepcopy(base);change(m);add(name,raw(m))
 # Valid surrogate pair/escaped key decoding, hostile prototype key remains unknown.
 add('escaped-title',manifest.replace('Синтетический'.encode(),b'\ud83d\udd14'),ok=True)
 add('prototype',manifest[:-1]+b',"__proto__":{}}')
 # Maximum manifest length accepts legal whitespace, +1 refuses before allocation.
 add('manifest-bound',manifest+b' '*(16384-len(manifest)),ok=True,chunks=[7,16384])
 add('manifest-over',manifest+b' '*(16385-len(manifest)))
 for name,c,ok in [('calendar-bound',cal+b' '*(12288-len(cal)),True),('calendar-duplicate',b'{"x":1,"x":2}',False),('calendar-bom',b'\xef\xbb\xbf{}',False),('calendar-utf8',b'{"x":"\xff"}',False),('calendar-surrogate',b'{"x":"\udc00"}',False),('calendar-deep',b'['*17+b'0'+b']'*17,False),('calendar-infinite',b'{"x":1e999}',False)]:
  m=copy.deepcopy(base);m['files'][0].update(size_bytes=len(c),sha256=sha(c));add(name,raw(m),[c],ok=ok,chunks=[7,16384])
 # User payload crosses chunk boundaries; same bytes can have two display entries.
 audio=bytes(range(256))*129;mh=sha(audio);m=copy.deepcopy(base)
 m['files'].append(dict(name='media/'+mh+'.mp3',size_bytes=len(audio),sha256=mh))
 entry=dict(id='user-a',title='User A',source='user',size_bytes=len(audio),sha256=mh,file='media/'+mh+'.mp3')
 m['media'].append(entry);m['media'].append(dict(entry,id='user-b',title='User B'))
 add('user-stream',raw(m),[cal,audio],ok=True,chunks=[7,16384])
 bad=copy.deepcopy(m);bad['media'][1]['size_bytes']+=1;add('user-size-mismatch',raw(bad),[cal,audio])
 bad=copy.deepcopy(m);bad['media']=bad['media'][:1];add('orphan-file',raw(bad),[cal,audio])
 bad=copy.deepcopy(m);bad['files']=bad['files'][:1];add('missing-file',raw(bad))
 bad=copy.deepcopy(m);bad['files'].append(bad['files'][1]);add('duplicate-file',raw(bad),[cal,audio,audio])
 bad=copy.deepcopy(m);bad['files'][1]['size_bytes']=524289;add('user-over',raw(bad),[cal,audio])
 # Independent maximum-sized media quota, streamed (not loaded by Lua codec).
 maximum=copy.deepcopy(base);payloads=[]
 for i in range(4):
  b=bytes([i])*524288;h=sha(b);payloads.append((h,b));maximum['files'].append(dict(name='media/'+h+'.mp3',size_bytes=len(b),sha256=h));maximum['media'].append(dict(id='u'+str(i),title='User',source='user',size_bytes=len(b),sha256=h,file='media/'+h+'.mp3'))
 maximum['files'][1:]=sorted(maximum['files'][1:],key=lambda f:f['sha256']);payloads.sort()
 add('media-quota',raw(maximum),[cal]+[b for _,b in payloads],ok=True,chunks=[16384])
 over=copy.deepcopy(maximum);h=sha(b'x');over['files'].append(dict(name='media/'+h+'.mp3',size_bytes=1,sha256=h));over['files'][1:]=sorted(over['files'][1:],key=lambda f:f['sha256']);add('media-over',raw(over))
 (d/'index.json').write_text(json.dumps(cases,separators=(',',':')))
 assert (d/'index.json').stat().st_size<16384
 subprocess.run(['node',str(HERE/'test.js'),tmp],cwd=ROOT,check=True)
 subprocess.run([os.environ.get('LUA','lua5.1'),str(HERE/'test.lua'),tmp],cwd=ROOT,check=True)
 print('[sbp] independent shared corpus:',len(cases),'vectors; golden SHA',sha(gold))
