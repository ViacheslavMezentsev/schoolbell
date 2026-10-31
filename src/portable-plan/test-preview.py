"""Common semantic corpus: compare complete successful Lua/JS proposals."""
import copy,hashlib,json,os,pathlib,subprocess,tempfile
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def raw(x):return json.dumps(x,ensure_ascii=False,separators=(',',':'))
fixture=json.loads((HERE/'fixture.json').read_text());base=json.loads(fixture['manifest']);calendar=json.loads(fixture['calendar'])
context=dict(draft=dict(schedules=[],plans=[],pre_minutes=2,pre_media='test',manual_media='test',mode='fixed',fixed_schedule='quiet'),timezone=base['timezone'],media=[dict(id='test',size_bytes=3,sha256=base['media'][0]['sha256'])],operation_id='0123456789abcdef0123456789abcdef',automatic_enabled=False,dirty=False,target='device',names=dict(plans={},schedules={}))
cases=[]
def case(name,change=lambda m,c,x:None,ok=True,code=None):
 m,c,x=copy.deepcopy(base),copy.deepcopy(calendar),copy.deepcopy(context);change(m,c,x)
 b=raw(c).encode();m['files'][0].update(size_bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
 cases.append((name,m,c,x,ok,code))
def user(m,c,x):
 v=m['media'][0];v.update(source='user',file='media/'+v['sha256']+'.mp3');v.pop('bundled_id');m['files'].append(dict(name=v['file'],size_bytes=v['size_bytes'],sha256=v['sha256']))
def old(m,c,x):
 s=copy.deepcopy(c['schedules'][0]);s.update(id='old',name='Existing');s['rows'][0]['media']='test';s['rows'][0]['pre']=False
 x['draft']['schedules'].append(s);x['draft']['plans'].append(dict(id='old-plan',name='Existing plan',start='2026-09-01',end='2026-09-02',schedule_ids=['old'],days='A.'))
case('base')
case('preserve-existing',old)
case('user',user)
case('pages',lambda m,c,x:x.update(target='pages'))
case('disabled-dependency',lambda m,c,x:(user(m,c,x),c['schedules'][0]['rows'][0].update(enabled=False)))
case('occupied-slot',lambda m,c,x:(user(m,c,x),x['media'].append(dict(id='user1',size_bytes=3,sha256=m['media'][0]['sha256']))))
case('reserved-missing-slot',lambda m,c,x:(user(m,c,x),x['draft'].update(manual_media='user1')))
case('pre-equal-content',lambda m,c,x:(old(m,c,x),x['draft']['schedules'][0]['rows'][0].update(pre=True)))
case('explicit-rename',lambda m,c,x:(old(m,c,x),c['schedules'][0].update(name='Existing'),x['names']['schedules'].update(normal='Renamed')))
case('quiet-range',lambda m,c,x:(c.update(schedules=[]),c['plans'][0].update(schedule_ids=[],days='..')))
case('cross-year',lambda m,c,x:c['plans'][0].update(start='2027-12-31',end='2028-01-02',days='AAA'))
case('leap-day',lambda m,c,x:c['plans'][0].update(start='2028-02-28',end='2028-03-01',days='AAA'))
case('timezone',lambda m,c,x:x['timezone'].update(posix='UTC1'),False,'timezone')
case('automatic',lambda m,c,x:x.update(automatic_enabled=True),False,'automatic_enabled')
case('dirty',lambda m,c,x:x.update(dirty=True),False,'dirty')
case('pages-user',lambda m,c,x:(user(m,c,x),x.update(target='pages')),False,'unsupported_media')
case('dynamic-after-eight',lambda m,c,x:(user(m,c,x),x['media'].extend(dict(id='user'+str(i),size_bytes=3,sha256=m['media'][0]['sha256'])for i in range(1,9))))
case('bundled-missing',lambda m,c,x:x.update(media=[]),False,'dependency')
case('bundled-changed',lambda m,c,x:x['media'][0].update(sha256='0'*64),False,'dependency')
case('missing-ref',lambda m,c,x:c['schedules'][0]['rows'][0].update(media='absent'),False,'dependency')
case('missing-pre',lambda m,c,x:c.update(pre_media='absent'),False,'dependency')
case('orphan-media',lambda m,c,x:m['media'].append(dict(m['media'][0],id='extra',bundled_id='1')),False,'dependency')
case('orphan-schedule',lambda m,c,x:c['schedules'].append(dict(c['schedules'][0],id='extra')),False,'dependency')
case('schedule-reference',lambda m,c,x:c['plans'][0].update(schedule_ids=['absent']),False,'dependency')
case('bad-date',lambda m,c,x:c['plans'][0].update(start='2027-02-29'),False,'format')
case('day-count',lambda m,c,x:c['plans'][0].update(days='A'),False,'format')
case('bad-code',lambda m,c,x:c['plans'][0].update(days='B.'),False,'format')
case('duplicate-schedule',lambda m,c,x:c['schedules'].append(copy.deepcopy(c['schedules'][0])),False,'format')
case('bad-row',lambda m,c,x:c['schedules'][0]['rows'][0].update(time='24:00'),False,'format')
case('nonboolean',lambda m,c,x:c['schedules'][0]['rows'][0].update(enabled=1),False,'format')
case('fraction',lambda m,c,x:c.update(pre_minutes=1.5),False,'format')
case('overlap',lambda m,c,x:(old(m,c,x),x['draft']['plans'][0].update(start='2027-08-31',end='2027-09-01')),False,'overlap')
case('name',lambda m,c,x:(old(m,c,x),c['schedules'][0].update(name='Existing')),False,'name_conflict')
case('pre-conflict-disabled',lambda m,c,x:(old(m,c,x),x['draft']['schedules'][0]['rows'][0].update(pre=True,enabled=False),x['draft'].update(pre_minutes=4)),False,'pre_conflict')
case('id-collision',lambda m,c,x:(old(m,c,x),x['draft']['plans'][0].update(id='imp-'+x['operation_id']+'-p1')),False,'conflict')
case('unknown-rename',lambda m,c,x:x['names']['plans'].update(absent='Name'),False,'format')
case('empty-rename',lambda m,c,x:x['names']['plans'].update(school=''),False,'format')
case('bad-operation',lambda m,c,x:x.update(operation_id='bad'),False,'format')
case('unknown-field',lambda m,c,x:c.update(active=True),False,'format')
case('no-plans',lambda m,c,x:c.update(plans=[]),False,'format')
case('result-size',lambda m,c,x:(old(m,c,x),x['draft']['plans'][0].update(start='1960-01-01',end='1991-08-15',days='.'*11550)),False,'size')
def many_missing(m,c,x):
 c['schedules']=[];c['plans'][0]['schedule_ids']=[]
 for i in range(4):
  sid='s'+str(i);c['plans'][0]['schedule_ids'].append(sid)
  c['schedules'].append(dict(id=sid,name=sid,color=1,rows=[dict(id='r'+str(j),time='08:30',media='missing',enabled=False,pre=False)for j in range(32)]))
case('bounded-blockers',many_missing,False,'dependency')
case('explicit-null',lambda m,c,x:c.update(pre_minutes=None),False,'format')
case('duplicate-plan-name',lambda m,c,x:c['plans'].append(dict(c['plans'][0],id='second',start='2028-01-01',end='2028-01-02')),False,'name_conflict')
case('quote-name',lambda m,c,x:c['plans'][0].update(name='Name "quoted" \\ path'))
with tempfile.TemporaryDirectory(prefix='sbp-preview-')as tmp:
 d=pathlib.Path(tmp)
 for name,m,c,x,_,_ in cases:
  (d/(name+'.manifest')).write_text(raw(m));(d/(name+'.calendar')).write_text(raw(c));(d/(name+'.context')).write_text(raw(x))
 (d/'index.json').write_text(raw([c[0]for c in cases]))
 outputs=[]
 for cmd in [['node',str(HERE/'test-preview.js')],[os.environ.get('LUA','lua5.1'),str(HERE/'test-preview.lua')]]:
  p=subprocess.run(cmd+[tmp],cwd=ROOT,check=True,text=True,stdout=subprocess.PIPE);outputs.append({v['name']:v['result']for v in map(json.loads,p.stdout.splitlines())})
 for name,m,c,x,ok,code in cases:
  a,b=outputs[0][name],outputs[1][name]
  for v in [a,b]:
   assert v['ok']==ok,(name,v['ok'],v['blockers'],v.get('candidate_bytes'))
   if code:assert code in [z['code']for z in v['blockers']],(name,v)
  if ok:
   assert a==b,(name,a,b)
   assert a['candidate']['schedules'][:len(x['draft']['schedules'])]==x['draft']['schedules']
   assert a['candidate']['plans'][:len(x['draft']['plans'])]==x['draft']['plans']
   for key in ['mode','fixed_schedule','manual_media']:assert a['candidate'][key]==x['draft'][key]
 assert outputs[0]['bounded-blockers']['blockers_truncated'] and len(outputs[0]['bounded-blockers']['blockers'])==64
 # Independent expected destination IDs/slots, not merely agreement of implementations.
 v=outputs[0]['base'];assert v['candidate']['plans'][0]['schedule_ids']==['imp-'+context['operation_id']+'-s1'];assert v['candidate']['schedules'][0]['rows'][0]['media']=='test'
 assert outputs[0]['occupied-slot']['mapping']['media'][0]['slot']=='user2'
 assert outputs[0]['reserved-missing-slot']['mapping']['media'][0]['slot']=='user2'
 assert outputs[0]['explicit-rename']['candidate']['schedules'][-1]['name']=='Renamed'
 print('[sbp preview] '+str(len(cases))+' shared semantic cases; successful proposals byte-count equivalent; snapshots unchanged')
