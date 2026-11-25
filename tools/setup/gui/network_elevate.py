"""Narrow UAC bridge: fixed helper, action/profile allowlists, GUID only."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

def arguments(action,guid,profile,helper,operation=""):
 if action not in ('prepare','restore','flash','confirm') or profile not in ('openwrt','factory'):raise ValueError('Invalid action/profile')
 args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(helper),'-Action',action,'-Profile',profile]
 if action in ('prepare','flash'):args+=['-AdapterGuid',str(uuid.UUID(guid))]
 if action in ('flash','confirm'):args+=['-Operation',str(uuid.UUID(operation))]
 return args

def elevate(args,progress=None):
 class SHELLEXECUTEINFO(ctypes.Structure):
  _fields_=[('cbSize',wintypes.DWORD),('fMask',wintypes.ULONG),('hwnd',wintypes.HWND),('lpVerb',wintypes.LPCWSTR),('lpFile',wintypes.LPCWSTR),('lpParameters',wintypes.LPCWSTR),('lpDirectory',wintypes.LPCWSTR),('nShow',ctypes.c_int),('hInstApp',wintypes.HINSTANCE),('lpIDList',ctypes.c_void_p),('lpClass',wintypes.LPCWSTR),('hkeyClass',wintypes.HKEY),('dwHotKey',wintypes.DWORD),('hIcon',wintypes.HANDLE),('hProcess',wintypes.HANDLE)]
 here=Path(__file__).resolve().parent
 shell=Path(os.environ['ProgramFiles'])/'PowerShell/7/pwsh.exe'
 if not shell.is_file():raise ValueError('PowerShell 7 is required')
 info=SHELLEXECUTEINFO();info.cbSize=ctypes.sizeof(info);info.fMask=0x40|0x400;info.lpVerb='runas';info.lpFile=str(shell);info.lpParameters=subprocess.list2cmdline(args);info.lpDirectory=str(here);info.nShow=0
 api=ctypes.WinDLL('shell32',use_last_error=True);api.ShellExecuteExW.argtypes=[ctypes.POINTER(SHELLEXECUTEINFO)];api.ShellExecuteExW.restype=wintypes.BOOL
 if not api.ShellExecuteExW(ctypes.byref(info)):
  if ctypes.get_last_error()==1223:return 'cancelled'
  raise OSError('Cannot start elevated helper')
 kernel=ctypes.WinDLL('kernel32',use_last_error=True)
 kernel.WaitForSingleObject.argtypes=[wintypes.HANDLE,wintypes.DWORD];kernel.WaitForSingleObject.restype=wintypes.DWORD
 kernel.GetExitCodeProcess.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD)];kernel.GetExitCodeProcess.restype=wintypes.BOOL
 kernel.CloseHandle.argtypes=[wintypes.HANDLE]
 try:
  while True:
   wait=kernel.WaitForSingleObject(info.hProcess,500)
   if progress:
    try:progress()
    except (OSError,ValueError):pass  # Reading progress must never abandon a running helper.
   if wait==0:break
   if wait!=258:raise OSError('Helper wait failed')
  code=wintypes.DWORD()
  if not kernel.GetExitCodeProcess(info.hProcess,ctypes.byref(code)):raise OSError('Missing helper result')
  return 'ok' if code.value==0 else 'busy' if code.value==4 else 'failed'
 finally:kernel.CloseHandle(info.hProcess)

def main():
 p=argparse.ArgumentParser();p.add_argument('action',choices=('prepare','restore','flash','confirm'));p.add_argument('--guid',default='');p.add_argument('--operation',default='');p.add_argument('--profile',choices=('openwrt','factory'),default='openwrt');a=p.parse_args()
 try:
  if os.name!='nt':raise ValueError('Windows only')
  args=arguments(a.action,a.guid,a.profile,Path(__file__).resolve().parent/'network_helper.ps1',a.operation)
  if a.action=='flash':
   previous=[None]
   def progress():
    path=Path(os.environ['ProgramData'])/'SchoolbellNetworkHelper-v1/flash-session.json'
    if not path.is_file() or path.stat().st_size>8192:return
    event=json.loads(path.read_text(encoding='utf-8-sig'))
    if event.get('schema')!=1 or event.get('operation')!=a.operation or event.get('profile')!=a.profile:return
    encoded=json.dumps(event,ensure_ascii=False)
    if previous[0]!=encoded:
     previous[0]=encoded;print(json.dumps({'flash_event':event},ensure_ascii=False),flush=True)
   result=elevate(args,progress)
  else:result=elevate(args)
 except Exception:result='failed'
 messages={'cancelled':'Запрос UAC отменён. Помощник не запускался.', 'busy':'Сетью уже занимается другой помощник. Дождитесь завершения.', 'failed':'Операция не подтверждена. При оставшихся настройках нажмите «Восстановить сеть».', 'ok':('Временный адрес подготовлен, прямой маршрут проверен. Сервер не запущен — Reset не нажимайте. После проверки восстановите сеть.' if a.action=='prepare' else 'DHCP и получение адреса подтверждены (либо сохранённого состояния не было).')}
 if a.action in ('flash','confirm') and result=='ok':
  messages['ok']='Сеть восстановлена. Проверьте загрузку и версию в интерфейсе роутера.' if a.action=='flash' else 'Проверка загрузки отмечена пользователем. Это не автоматическая проверка версии.'
 print(json.dumps(dict(helper_result=result,message=messages[result]),ensure_ascii=False),flush=True)
 return 0 if result in ('ok','cancelled') else 1
if __name__=='__main__':raise SystemExit(main())
