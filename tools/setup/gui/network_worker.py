"""Read-only Windows inventory and fresh snapshot planning for the GUI."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
HERE=Path(__file__).resolve().parent
if not (HERE/'network_plan.py').exists():sys.path.insert(0,str(HERE.parent))
from network_plan import plan

MESSAGES={
 'adapter-physical':'Нужен физический адаптер.', 'adapter-usb':'Выберите отдельный USB–Ethernet-адаптер.',
 'adapter-dhcp':'Включите DHCP на выделенном адаптере.', 'adapter-link-up':'Проверьте кабель и питание: нет соединения.',
 'adapter-media':'Нужен Ethernet-адаптер.', 'pending-restore':'Остались сетевые настройки предыдущего запуска: сначала восстановите сеть.',
 'manual-address':'На адаптере есть ручные адреса.', 'reserved-address-in-use':'Адрес профиля уже занят на компьютере.',
 'conflicting-route':'Обнаружен пересекающийся прямой или более точный маршрут.', 'tftp-port-busy':'UDP 69 или 1069 занят.',
 'gateway-route-recheck':'Есть фоновый маршрут через шлюз. Перед передачей потребуется проверить прямой путь.'}

def evaluate(snapshot,guid='',profile='openwrt',model=''):
 choices=[dict(guid=a['guid'],label=a['name']+' · '+a.get('description','')+(' · нет соединения' if not a['link_up'] else '')) for a in snapshot['adapters'] if a['physical'] and a['media']=='ethernet']
 if not guid:return dict(choices=choices,message='Выберите отдельный USB–Ethernet-адаптер. IP-адрес пока не требуется.',plan=None)
 result=plan(snapshot,guid,profile,model)
 lines=['Предварительная проверка: препятствий в снимке нет.' if result['eligible'] else 'Есть препятствия для продолжения.']
 lines.extend(MESSAGES[c] for c in result['blockers']+result['warnings'])
 lines+=['Профиль: '+result['image']['label'], 'Сеть не изменена. Образ ещё не проверен. Сервер не запущен — Reset не нажимайте.']
 return dict(choices=choices,message='\n'.join(lines),plan=result)

def main():
 p=argparse.ArgumentParser();p.add_argument('--guid',default='');p.add_argument('--profile',choices=('openwrt','factory'),default='openwrt');p.add_argument('--model',default='');a=p.parse_args()
 if os.name!='nt':raise ValueError('Windows inventory is only supported on Windows')
 shell=Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
 result=subprocess.run([str(shell),'-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(HERE/'network_snapshot.ps1')],capture_output=True,timeout=35,check=True)
 if len(result.stdout)>1024*1024:raise ValueError('Inventory response too large')
 print(json.dumps(evaluate(json.loads(result.stdout.decode('utf-8-sig')),a.guid,a.profile,a.model),ensure_ascii=False))
if __name__=='__main__':
 try:main()
 except Exception:
  print(json.dumps(dict(error='Не удалось прочитать настройки сети. Проверьте доступ к системным средствам Windows и повторите проверку.'),ensure_ascii=False));sys.exit(1)
