"""Check built Pages routes/assets and demo isolation without device requests."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import json, hashlib, re
root=Path(__file__).resolve().parents[1]
out=root/'out/site'
class Page(HTMLParser):
 def __init__(self,text):
  super().__init__();self.links=[];self.ids=set();self.feed(text)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.add(a['id'])
  for key in ('src','href'):
   if key in a:self.links.append(a[key])
pages={p:Page(p.read_text()) for p in out.rglob('*.html')}
for path,page in pages.items():
 text=path.read_text();assert '<%=' not in text and '{{' not in text,path
 for link in page.links:
  u=urlsplit(link)
  if u.scheme or u.netloc:continue
  assert not u.path.startswith('/'),(path,link)
  target=(path.parent/unquote(u.path)).resolve() if u.path else path.resolve()
  assert target == out.resolve() or out.resolve() in target.parents,(path,link)
  if target.is_dir():target=target/'index.html'
  assert target.is_file(),(path,link)
  if u.fragment and target.suffix=='.html':assert unquote(u.fragment) in pages[target].ids,(path,link)
home=(out/'index.html').read_text()
for required in ['page-tabs','demo-notice','demo-migrate','feedback-build','portable']:
 assert required in home,required
assert not (out/'schoolbell').exists(),'No nested duplicate demo or project landing page'
assert home.index('assets/demo.js')<home.index('assets/traffic.js')<home.index('assets/session.js')
assert 'https://github.com/ViacheslavMezentsev/schoolbell' in home
assert 'openwrt-modbus-core/issues' not in home
assert 'device-plan-export:start' not in home and 'device-plan-import:start' not in home
info=json.loads((out/'build-info.json').read_text());assert re.fullmatch('[a-f0-9]{40}',info['commit'])
assert info['commit'] in home and info['built_at_utc'] in home
for name in ['test','0','1','2','3','4']:
 assert (out/'assets'/f'{name}.mp3').read_bytes()==(root/'assets/melodies'/f'{name}.mp3').read_bytes()
for name in ['style.css','theme.js','ranges.js']:
 assert (out/'assets'/name).read_bytes()==(root/'ui/root/www/schoolbell-test'/name).read_bytes()
assert not list(out.rglob('*.bin')) and not list(out.rglob('*.ipk')) and not list(out.rglob('*.sbb'))
print('PASS Pages: root UI, guide/training/device routes and anchors, shared assets, media bytes, build provenance, no firmware or device API panels')

assert './licenses/' in home
assert (out/'licenses/LICENSE').read_bytes()==(root/'LICENSE').read_bytes()
assert (out/'licenses/NOTICE').read_bytes()==(root/'NOTICE').read_bytes()
assert (out/'licenses/LICENSE-SCOPE.txt').read_bytes()==(root/'packaging/licenses/SCOPE.txt').read_bytes()
assert (out/'licenses/AUDIO-NOTICE.txt').read_bytes()==(root/'packaging/openwrt/package/usr/share/modbus-schoolbell/NOTICE').read_bytes()
assert (out/'licenses/media-manifest.json').read_bytes()==(root/'assets/melodies/manifest.json').read_bytes()
for name in ['LUCI-LICENSE','portable-zones.NOTICE']:
 assert (out/'licenses'/name).read_bytes()==(root/'site'/name).read_bytes()
 assert (out/'assets'/name).read_bytes()==(root/'site'/name).read_bytes()
assert (out/'assets/media-manifest.json').read_bytes()==(root/'assets/melodies/manifest.json').read_bytes()
print('PASS Pages license navigation, MIT, scope, audio manifest and LuCI notice delivery')

# Device HTML must carry correct feedback links itself; Pages must not repair it.
feedback_base='https://github.com/ViacheslavMezentsev/schoolbell/issues'
guides=['https://viacheslavmezentsev.github.io/schoolbell/guide.html',
        'https://viacheslavmezentsev.github.io/schoolbell/guide.en.html']
expected={feedback_base,feedback_base+'/new?template=bug_report.yml',
          feedback_base+'/new?template=feature_request.yml',*guides}
for text in [home,(root/'ui/root/usr/lib/lua/luci/view/schoolbell_test.htm').read_text()]:
 panel=text.split('<section id="panel-feedback"',1)[1].split('</section>',1)[0]
 assert set(Page(panel).links)==expected
 assert 'openwrt-modbus-core' not in panel
 assert 'Если формы ещё недоступны' not in panel
for name in ['bug_report.yml','feature_request.yml']:
 form=(root/'.github/ISSUE_TEMPLATE'/name).read_text()
 assert all(url in form for url in guides)
 assert '        - core' not in form and '        - rover' not in form
 assert 'id: component' in form and 'validations:' in form
config=(root/'.github/ISSUE_TEMPLATE/config.yml').read_text()
assert all(url in config for url in guides)
print('PASS Feedback: device/Pages share exact schoolbell issue-form and guide links; templates exist and target Schoolbell')

# Keep the HTTP validator in step with the actual packaged recording.
test_digest=hashlib.sha256((root/'assets/melodies/test.mp3').read_bytes()).hexdigest()
assert f"""M.test_etag='"{test_digest}"'""" in (root/'src/lua/schoolbell/media_ids.lua').read_text()
