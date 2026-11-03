#!/usr/bin/env python3
"""Static GitHub Pages, sharing the router UI sources; no network or device calls."""
from pathlib import Path
from license_materials import write_materials, materials
import html, re, shutil, sys, subprocess, datetime, json, hashlib
root=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'out/site'
out.mkdir(parents=True,exist_ok=True)
write_materials(out/'licenses', 'pages')
license_links=''.join('<li><a href="'+html.escape(name)+'">'+html.escape(name)+'</a></li>' for name in sorted(materials('pages')))
(out/'licenses/index.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><title>Лицензии / Licenses</title><h1>Лицензии / Licenses</h1><p>Собственный код — MIT. Аудио и сторонние материалы имеют отдельный статус. Own code is MIT; audio and third-party materials have separate terms.</p><ul>'+license_links+'</ul><p><a href="../">Вернуться в интерфейс / Back to demo</a></p></html>')
try:
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
 dirty=bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip())
except (OSError,subprocess.CalledProcessError):
 commit='unknown';dirty=True
built=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds').replace('+00:00','Z')
metadata={'built_at_utc':built,'commit':commit,'dirty':dirty}
(out/'build-info.json').write_text(json.dumps(metadata,indent=2)+'\n')
label='Сборка: '+built+' · commit '+commit[:12]+(' · локальные изменения' if dirty else '')
provenance='<p class="build-info">'+html.escape(label)+'</p>'
version=re.search(r'^Version: (.+)$',(root/'packaging/openwrt/package/CONTROL/control').read_text(),re.M)[1]
source=root/'ui/root'
shutil.copyfile(root/'site/style.css',out/'style.css')
shutil.copyfile(source/'www/schoolbell-test/theme.js',out/'theme.js')
(out/'.nojekyll').write_text('')
demo=out;assets=demo/'assets';assets.mkdir(parents=True,exist_ok=True)
for p in (source/'www/schoolbell-test').iterdir():
 text=p.read_text()
 if p.suffix=='.js':
  text=text.replace('на устройстве','в демо').replace('на устройство','в демо').replace('с устройства','из браузера').replace('с устройством','с локальной моделью').replace('на роутере','в демо').replace('на роутер','в демо').replace('с роутера','из браузера').replace('с роутером','с локальной моделью').replace('Проверьте вход в LuCI, сеть','Проверьте файл').replace('вход LuCI','демо')
 if p.name=='schedules.js':
  marker='window.schoolbellEditor={'
  assert text.count(marker)==1
  text=text.replace(marker,marker+'portableSnapshot:function(){return {draft:draft?JSON.parse(JSON.stringify(draft)):null,dirty:dirty||formPending,formPending:formPending,busy:busy||activationLock,reconcile:reconcile,revision:revision};},',1)
 (assets/p.name).write_text(text)
shutil.copyfile(root/'site/demo.js',assets/'demo.js')
for name in ['test','0','1','2','3','4']:
 shutil.copyfile(root/('assets/melodies/'+name+'.mp3'),assets/(name+'.mp3'))
shutil.copyfile(root/'packaging/openwrt/package/usr/share/modbus-schoolbell/NOTICE',assets/'NOTICE.txt')
shutil.copyfile(root/'assets/melodies/manifest.json',assets/'media-manifest.json')
for name in ['codec','export','preview']:
 shutil.copyfile(root/('src/portable-plan/'+name+'.js'),assets/('portable-'+name+'.js'))
for name in ['portable-pages.js','portable-ui.js','portable.css','portable-zones.NOTICE','LUCI-LICENSE']:
 shutil.copyfile(root/'site'/name,assets/name)
titles=['Тестовый звонок','[Короткая] Время','Шутка Баха','Гостья из будущего','Князь Игорь','Усатый нянь']
inventory=[]
for name,title in zip(['test','0','1','2','3','4'],titles):
 data=(assets/(name+'.mp3')).read_bytes()
 inventory.append(dict(id=name,title=title,size_bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
config=dict(version=version,zones=json.loads((root/'site/portable-zones.json').read_text()),media=inventory)
(assets/'portable-config.js').write_text('window.SchoolbellPortableConfig='+json.dumps(config,ensure_ascii=False)+';\n')
text=(source/'usr/lib/lua/luci/view/schoolbell_test.htm').read_text()
text=re.sub(r'<!-- device-plan-export:start -->.*?<!-- device-plan-export:end -->','',text,flags=re.S)
text=re.sub(r'<script src="/schoolbell-test/plan-export.js[^"]*"></script>','',text)
text=re.sub(r'<!-- device-plan-import:start -->.*?<!-- device-plan-import:end -->','',text,flags=re.S)
text=re.sub(r'<script src="/schoolbell-test/plan-import.js[^"]*"></script>','',text)
values={'metrics_url':'./demo-api/metrics','system_url':'./demo-api/system','session_url':'./demo-api/session','login_url':'./','auth_user':'Демо без входа','trust_url':'./demo-api/clock-trust','backup_url':'./demo-api/backup','media_url':'./demo-api/media','automatic_url':'./demo-api/automatic','controls_url':'./demo-api/controls','manual_url':'./demo-api/no-router','preview_url':'./demo-api/preview','schedules_url':'./demo-api/load','save_url':'./demo-api/save','clock_url':'./demo-api/clock','journal_url':'./demo-api/journal','timezone_url':'./demo-api/timezone','sample_url':'./assets/test.mp3','play_url':'./demo-api/no-router','module_version':version+' · Демо','core_version':'не подключено','token':'demo'}
for key,value in values.items():text=text.replace('<%=pcdata('+key+')%>',html.escape(value,quote=True))
text=text.replace("<%=url('admin')%>",'https://github.com/ViacheslavMezentsev/schoolbell').replace('← Управление устройством LuCI','← Репозиторий проекта').replace('← Управление роутером LuCI','← Репозиторий проекта')
text=text.replace('/schoolbell-test/','./assets/')
text=text.replace('<nav class="page-tabs"', '<div class="demo-notice-row"><details id="demo-notice" class="plan-workflow demo-notice"><summary><strong>ДЕМО · оборудование не подключено.</strong><span class="collapse-hint">Подробности ▾</span></summary><p>Календарные планы можно редактировать без устройства. Расписания и часовой пояс изменяются только в этом браузере. Автозвонков нет.</p><p id="demo-storage">Данные демо сохраняются локально.</p><p id="demo-migration-status"></p><button id="demo-migrate" type="button" hidden>Перенести прежний черновик</button><button id="demo-boot" type="button">Имитировать перезагрузку</button><button id="demo-reset" type="button">Сбросить демо</button></details><a class="demo-guide" href="./guide.html">Руководство</a><a class="demo-guide" href="./training.html">Обучение</a></div><nav class="page-tabs"',1)
text=text.replace('Подготовьте расписания и сохраните их на роутере.','Попробуйте расписания и календарь на тестовых данных.')
text=text.replace('Инженерная установка','Демонстрация интерфейса').replace('На роутере · оценка между опросами','Демо-часы · выбранная зона').replace('Сохраняется на роутере','Сохраняется в браузере').replace('Настройка сохраняется на роутере и действует для всех его приложений.','Настройка меняет только часовой пояс этого демо, не устройства или компьютера.')
text=text.replace('id="router-play" type="submit"','id="router-play" type="submit" disabled').replace('▶ Позвонить на роутере','Недоступно в демо · нет роутера').replace('<p id="router-result" role="status"></p>','<p id="router-result" role="status">В демо доступен только звук браузера.</p>')
text=re.sub(r'(?=<script src="\./assets/traffic\.js(?:\?[^"]*)?">)', '<script src="./assets/ranges.js"></script><script src="./assets/demo.js"></script>', text, count=1)
marker='<h2>Календарные планы</h2>'
assert text.count(marker)==1
text=text.replace(marker,marker+(root/'site/portable-panel.html').read_text(),1)
text=text.replace('</head>','<link rel="stylesheet" href="./assets/portable.css"></head>')
scripts=''.join('<script src="./assets/'+name+'.js"></script>' for name in ['portable-codec','portable-export','portable-preview','portable-config','portable-pages','portable-ui'])
text=text.replace('</body>',scripts+'</body>')
assert '<%=' not in text,'unresolved template'
# Embed provenance at build time; never infer it from the current remote branch.
author_marker='Соавтор: Codex (OpenAI), ИИ-помощник в разработке.</p>'
assert text.count(author_marker)==1
build_details='<div id="feedback-build" class="feedback-build"><strong>Сборка демо Pages</strong><p>Дата (UTC): '+html.escape(built)+'</p><p>Git commit: <code>'+html.escape(commit)+'</code></p>'+('<p>Собрано с локальными изменениями.</p>' if dirty else '')+'</div>'
text=text.replace(author_marker,author_marker+build_details,1)
text=text.replace('</footer>','<p><a href="./licenses/">Лицензии / Licenses</a></p>'+provenance+'</footer>')
(demo/'index.html').write_text(text)
print('Built static site:',out)

# Retain old incoming links without maintaining a second calendar editor.
(demo/'ranges.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=./"><title>Календарные планы</title><a href="./">Открыть рабочий редактор календарных планов</a></html>')

# Pages-only guide: no changes to the installed module or its package.
shutil.copyfile(root/'site/guide.css',out/'guide.css')
for lang,name in [('ru','guide.html'),('en','guide.en.html')]:
 page=(root/'site'/('schoolbell-'+name)).read_text().replace('{{VERSION}}',html.escape(version))
 for marker,diagram in [('{{BENCH}}','bench'),('{{AUDIO}}','audio')]:
  page=page.replace(marker,(root/'site/diagrams'/(diagram+'.'+lang+'.svg')).read_text())
 footer=provenance if lang=='ru' else provenance.replace('Сборка:','Build:').replace('локальные изменения','local changes')
 (demo/name).write_text(page.replace('</footer>',footer+'</footer>'))

# Device references are static, bilingual, and outside the hardware demo.
shutil.copytree(root/"site/devices",out/"devices",dirs_exist_ok=True)

# Pages-only practical training, sharing guide theme and build provenance.
for lang,name in [('ru','training.html'),('en','training.en.html')]:
 page=(root/'site'/('schoolbell-'+name)).read_text().replace('{{VERSION}}',html.escape(version))
 footer=provenance if lang=='ru' else provenance.replace('Сборка:','Build:').replace('локальные изменения','local changes')
 (demo/name).write_text(page.replace('</footer>',footer+'</footer>'))
