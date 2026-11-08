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
for required in ['page-tabs','simulator-panel','demo-migrate','feedback-build','portable']:
 assert required in home,required
assert not (out/'schoolbell').exists(),'No nested duplicate demo or project landing page'
assert home.index('assets/demo.js')<home.index('assets/session.js')
assert 'id="traffic-panel"' not in home and 'assets/traffic.js' not in home
assert not (out/'assets/traffic.js').exists()
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
repository='https://github.com/ViacheslavMezentsev/schoolbell'
feedback_base=repository+'/issues'
guides=['https://viacheslavmezentsev.github.io/schoolbell/guide.html',
        'https://viacheslavmezentsev.github.io/schoolbell/guide.en.html']
expected={repository,feedback_base,feedback_base+'/new?template=bug_report.yml',
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

# The bell range controls belong only to the schedules panel.
for markup in [(out/'index.html').read_text(),(root/'ui/root/usr/lib/lua/luci/view/schoolbell_test.htm').read_text()]:
    schedules=markup.split('id="panel-schedules"',1)[1].split('id="panel-',1)[0]
    for name in ('rows-prev','rows-range','rows-next'):
        marker=f'id="{name}"'
        assert markup.count(marker)==1 and marker in schedules, name

    toolbar=schedules.split('<div class="list-toolbar">',1)[1].split('<div class="table-scroll">',1)[0]
    assert all(f'id="{key}"' in toolbar for key in ('row-add','rows-clear','rows-prev','rows-next'))
    help_panel=markup.split('id="panel-help"',1)[1].split('</section>',1)[0]
    assert '<h2>' not in help_panel and help_panel.count('<details class="details">')==4
    media=markup.split('id="panel-media"',1)[1].split('id="media-rows"',1)[0]
    media_toolbar=media.split('<div class="list-toolbar">',1)[1].split('<div class="table-scroll">',1)[0]
    assert all(f'id="{key}"' in media_toolbar for key in ('media-add','media-refresh','media-prev','media-next'))

# Pages identifies itself once, without fabricated hardware resource readings.
assert '<strong class="demo-label">Демо</strong>' in home
assert len(re.findall(r"\bДемо\b",home))==1
assert "font-weight:700;color:var(--warning-text)" in home
assert "Демо Flash" not in (out/"assets/cpu.js").read_text()

assert home.index('id="metrics-panel"') < home.index('id="simulator-panel"') < home.index('id="session-status"')
assert 'id="simulator-panel" class="metrics-panel simulator-panel"' in home
assert 'id="simulator-panel" class="metrics-panel simulator-panel" open' not in home
assert (out/"assets/simulator-ui.js").is_file()

# Local-data actions belong to the simulator; guides remain available outside it.
assert 'id="demo-notice"' not in home
assert 'id="demo-boot"' not in home
panel=home[home.index('id="simulator-panel"'):home.index('id="session-status"')]
for control in ['demo-storage','demo-migration-status','demo-migrate','demo-reset','simulator-reboot']:
 assert panel.count('id="'+control+'"')==1,control
assert '<a class="demo-guide" href="./guide.html">Руководство</a>' in home
assert '<a class="demo-guide" href="./training.html">Обучение</a>' in home
