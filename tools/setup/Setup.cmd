@echo off
setlocal EnableExtensions DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
set "setup_shell="
if exist "%ProgramW6432%\PowerShell\7\pwsh.exe" set "setup_shell=%ProgramW6432%\PowerShell\7\pwsh.exe"
if not defined setup_shell if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "setup_shell=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined setup_shell for /f "delims=" %%P in ('where.exe pwsh.exe 2^>nul') do if not defined setup_shell set "setup_shell=%%P"
if not defined setup_shell (
    echo PowerShell 7 not found; using Windows PowerShell 5.1.
    set "setup_shell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)
echo PowerShell: "%setup_shell%"
"%setup_shell%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" %*
set "rc=%errorlevel%"
popd
pause
exit /b %rc%
