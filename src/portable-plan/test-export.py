"""Independent export oracle; shared Lua/JS inputs, exact wire bytes and preview."""
import copy,hashlib,json,os,pathlib,subprocess,tempfile,re
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def canonical(v):
 if isinstance(v,str):return '"'+re.sub(r'[\x00-\x1f\\"]',lambda m:'\\u%04x'%ord(m[0]),v)+'"'
 if isinstance(v,list):return '['+','.join(map(canonical,v))+']'
 if isinstance(v,dict):return '{'+','.join(canonical(k)+':'+canonical(v[k])for k in sorted(v))+'}'
 return json.dumps(v,separators=(',',':'))
def raw(v):return canonical(v).encode()
fixture=json.loads((HERE/'fixture.json').read_text());cal=json.loads(fixture['calendar'])
cal['pre_media']='test';cal['schedules'][0]['rows'][0]['media']='test'
base=dict(draft=dict(cal,mode='annual',fixed_schedule='quiet',manual_media='test'),selected=['school'],timezone=dict(name='Etc/UTC',posix='UTC0'),exporter=dict(name='schoolbell-device',version='5.1.18'),media=[dict(id='test',title='Тест "название"',size_bytes=3,sha256=sha(b'abc'))])
cases=[]
def case(name,change=lambda x,p:None,ok=True,fault=None,early=False):
 x=copy.deepcopy(base);p={};change(x,p);cases.append((dict(name=name,ok=ok,fault=fault,early=early),x,p))
def user(x,p,n=1,data=b'synthetic MP3 bytes',row=True):
 slot='user'+str(n);p[slot]=data;x['media'].append(dict(id=slot,title='Мелодия '+str(n),size_bytes=len(data),sha256=sha(data)))
 if row:
  s=x['draft']['schedules'][0];s['rows'].append(dict(s['rows'][0],id='r'+str(n),media=slot,enabled=False))
def second(x,p):
 d=x['draft'];d['schedules'].append(dict(id='unused',name='Unused',rows=[],color=9));d['plans'].append(dict(id='next',name='Next',start='2028-01-01',end='2028-01-02',schedule_ids=['unused'],days='..'))
case('base')
case('pages',lambda x,p:x['exporter'].update(name='schoolbell-pages'))
case('user',user)
case('disabled-user',lambda x,p:(user(x,p),x['draft']['schedules'][0]['rows'][0].update(enabled=False)))
case('dedup',lambda x,p:(user(x,p),user(x,p,2)))
case('dynamic-twelve',lambda x,p:[user(x,p,i)for i in range(1,13)])
case('pre-only-user',lambda x,p:(user(x,p,row=False),x['draft'].update(pre_media='user1')))
case('subset',second)
case('selected-order',lambda x,p:(second(x,p),x.update(selected=['next','school'])))
case('quiet',lambda x,p:(x['draft'].update(schedules=[]),x['draft']['plans'][0].update(schedule_ids=[],days='..')))
case('unused-listed',lambda x,p:(second(x,p),x['draft']['plans'][0]['schedule_ids'].append('unused')))
case('default-color',lambda x,p:x['draft']['schedules'][0].pop('color'))
case('legacy-year',lambda x,p:(x['draft'].update(plans=[dict(year=2028,schedule_ids=['normal'],days='A'+'.'*365)]),x.update(selected=['year-2028'])))
case('cross-year',lambda x,p:x['draft']['plans'][0].update(start='2027-12-31',end='2028-01-02',days='AAA'))
case('upload-limit',lambda x,p:user(x,p,data=b'x'*65536))
case('over-upload-limit',lambda x,p:user(x,p,data=b'x'*65537))
case('max-file',lambda x,p:user(x,p,data=b'x'*524288))
case('max-total',lambda x,p:[user(x,p,i,bytes([i])*524288)for i in range(1,5)])
case('no-selection',lambda x,p:x.update(selected=[]),False,early=True)
case('duplicate-selection',lambda x,p:x.update(selected=['school','school']),False,early=True)
case('unknown-selection',lambda x,p:x.update(selected=['absent']),False,early=True)
case('missing-bundled',lambda x,p:x.update(media=[]),False,early=True)
case('missing-user',lambda x,p:(user(x,p),x['media'].pop()),False,early=True)
case('pages-user',lambda x,p:(user(x,p),x['exporter'].update(name='schoolbell-pages')),False,early=True)
case('invalid-draft',lambda x,p:x['draft']['plans'][0].update(days='A'),False,early=True)
case('unknown-field',lambda x,p:x.update(active=True),False,early=True)
case('bad-title',lambda x,p:x['media'][0].update(title=''),False,early=True)
case('duplicate-inventory',lambda x,p:x['media'].append(copy.deepcopy(x['media'][0])),False,early=True)
case('conflicting-dedup-size',lambda x,p:(user(x,p),user(x,p,2),x['media'][-1].update(size_bytes=1)),False,early=True)
case('bad-version',lambda x,p:x['exporter'].update(version='05.1.18'),False,early=True)
case('large-file',lambda x,p:user(x,p,data=b'x'*524289),False,early=True)
case('large-total',lambda x,p:[user(x,p,i,bytes([i])*524288)for i in range(1,6)],False,early=True)
case('changed-payload',lambda x,p:(user(x,p),p.update(user1=b'Z'*len(p['user1']))),False)
case('short-payload',lambda x,p:(user(x,p),p.update(user1=b'x')),False)
case('trailing-payload',lambda x,p:(user(x,p),p.update(user1=p['user1']+b'x')),False)
case('open-failure',user,False,'open')
case('read-failure',user,False,'read')
case('emit-failure',user,False,'emit')
def expected(x,p):
 d=x['draft'];plans=[]
 for plan in d['plans']:
  v=copy.deepcopy(plan)
  if 'year'in v:
   y=v.pop('year');v.update(id='year-'+str(y),name='План '+str(y),start=f'{y:04}-01-01',end=f'{y:04}-12-31')
  if v['id']in x['selected']:plans.append(v)
 needed={k for v in plans for k in v['schedule_ids']};schedules=[]
 for i,s in enumerate(d['schedules']):
  if s['id']in needed:
   v=copy.deepcopy(s);v.setdefault('color',i%16+1);schedules.append(v)
 c=dict(plans=plans,schedules=schedules,pre_minutes=d['pre_minutes'],pre_media=d['pre_media']);craw=raw(c)
 used={d['pre_media']}|{r['media']for s in schedules for r in s['rows']};media=[];payload={}
 legacy=['test','0','1','2','3','4']+['user'+str(i)for i in range(1,9)]
 for slot in legacy+sorted(used-set(legacy)):
  if slot not in used:continue
  v=copy.deepcopy(next(v for v in x['media']if v['id']==slot));v['source']='user'if slot.startswith('user')else'bundled'
  if v['source']=='user':v['file']='media/'+v['sha256']+'.mp3';payload[v['file']]=p[slot]
  else:v['bundled_id']=slot
  media.append(v)
 files=[dict(name='calendar.json',size_bytes=len(craw),sha256=sha(craw))]+[dict(name=k,size_bytes=len(payload[k]),sha256=sha(payload[k]))for k in sorted(payload)]
 m=raw(dict(format='schoolbell-plan/2' if sum(v['source']=='user' for v in media)>8 else 'schoolbell-plan/1',exporter=x['exporter'],timezone=x['timezone'],files=files,media=media))
 return b'SBPLAN1\n'+f'{len(m):08}\n'.encode()+sha(m).encode()+b'\n'+m+craw+b''.join(payload[k]for k in sorted(payload))
with tempfile.TemporaryDirectory(prefix='sbp-export-')as tmp:
 d=pathlib.Path(tmp)
 for v,x,p in cases:
  (d/(v['name']+'.json')).write_bytes(raw(x))
  for slot,b in p.items():(d/(v['name']+'.'+slot)).write_bytes(b)
 (d/'index.json').write_text(json.dumps([v for v,_,_ in cases]))
 for cmd in [['node',str(HERE/'test-export.js')],[os.environ.get('LUA','lua5.1'),str(HERE/'test-export.lua')]]:
  subprocess.run(cmd+[tmp],cwd=ROOT,check=True,stdout=subprocess.PIPE,text=True)
 for v,x,p in cases:
  if v['ok']:
   oracle=expected(x,p)
   for lang in ['js','lua']:assert (d/(v['name']+'.'+lang+'.sbp')).read_bytes()==oracle,(v['name'],lang)
 print('[sbp export] '+str(len(cases))+' shared cases; independent exact-byte oracle, decode/preview and stream faults passed')
