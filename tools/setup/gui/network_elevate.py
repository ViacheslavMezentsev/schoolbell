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

def arguments(action,guid,profile,helper):
 if action not in ('prepare','restore') or profile not in ('openwrt','factory'):raise ValueError('Invalid action/profile')
 args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(helper),'-Action',action,'-Profile',profile]
 if action=='prepare':args+=['-AdapterGuid',str(uuid.UUID(guid))]
 return args

def elevate(args):
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
  if kernel.WaitForSingleObject(info.hProcess,0xffffffff)!=0:raise OSError('Helper wait failed')
  code=wintypes.DWORD()
  if not kernel.GetExitCodeProcess(info.hProcess,ctypes.byref(code)):raise OSError('Missing helper result')
  return 'ok' if code.value==0 else 'busy' if code.value==4 else 'failed'
 finally:kernel.CloseHandle(info.hProcess)

def main():
 p=argparse.ArgumentParser();p.add_argument('action',choices=('prepare','restore'));p.add_argument('--guid',default='');p.add_argument('--profile',choices=('openwrt','factory'),default='openwrt');a=p.parse_args()
 try:
  if os.name!='nt':raise ValueError('Windows only')
  result=elevate(arguments(a.action,a.guid,a.profile,Path(__file__).resolve().parent/'network_helper.ps1'))
 except Exception:result='failed'
 messages={'cancelled':'Запрос UAC отменён. Помощник не запускался.', 'busy':'Сетью уже занимается другой помощник. Дождитесь завершения.', 'failed':'Операция не подтверждена. При оставшихся настройках нажмите «Восстановить сеть».', 'ok':('Временный адрес подготовлен, прямой маршрут проверен. Сервер не запущен — Reset не нажимайте. После проверки восстановите сеть.' if a.action=='prepare' else 'Конфигурация DHCP восстановлена (либо сохранённого состояния не было). Получение адреса зависит от DHCP-сервера.')}
 print(json.dumps(dict(helper_result=result,message=messages[result]),ensure_ascii=False))
 return 0 if result in ('ok','cancelled') else 1
if __name__=='__main__':raise SystemExit(main())
