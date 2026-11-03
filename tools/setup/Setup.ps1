#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly,[switch]$InstallOnly,[switch]$RestoreNetwork)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
$python=Join-Path $PSScriptRoot 'python\python.exe'
$stateDir=Join-Path $env:LOCALAPPDATA 'SchoolbellSetup'
$state=Join-Path $stateDir 'network.json'
function Run-Python([string[]]$Arguments) {
    & $python @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Ошибка этапа Python ($LASTEXITCODE). Подробности выше." }
}
function Restore-Cable($saved) {
    $adapter=Get-NetAdapter | Where-Object { [string]$_.InterfaceGuid -eq $saved.guid }
    if (!$adapter) {throw 'Подключите исходный Ethernet-адаптер и повторите -RestoreNetwork.'}
    Get-NetFirewallRule -Name $saved.rule -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    foreach ($ip in '192.168.0.225','192.168.1.2') {
        Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $adapter.ifIndex -IPAddress $ip -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
    }
    Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp Enabled
    Remove-Item -LiteralPath $state
}
function Set-CableIP($index,$ip) {
    $network=$ip.Substring(0,$ip.LastIndexOf('.'))+'.0/24'
    if (Get-NetRoute -DestinationPrefix $network -ErrorAction SilentlyContinue | Where-Object InterfaceIndex -ne $index) {
        throw "Конфликт маршрута $network. Отключите пересекающуюся сеть/VPN."
    }
    New-NetIPAddress -InterfaceIndex $index -IPAddress $ip -PrefixLength 24 -PolicyStore ActiveStore | Out-Null
}
if (!$RestoreNetwork) {
    if (!(Test-Path 'SHA256SUMS')) {throw 'Распакуйте полный ZIP, включая python, firmware и bundle.'}
    foreach ($line in Get-Content SHA256SUMS) {
        if ($line -notmatch '^([0-9a-f]{64})  ([\w./+-]+)$') {throw 'Ошибка списка SHA256SUMS.'}
        $hash=$Matches[1]; $file=$Matches[2]
        if ([IO.Path]::IsPathRooted($file) -or $file.Split('/') -contains '..') {throw 'Недопустимый путь в SHA256SUMS.'}
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $hash) {throw "Повреждён файл $file"}
    }
    Get-Command ssh.exe -ErrorAction Stop | Out-Null
    Run-Python @('install.py','--check')
    if ($CheckOnly) { Run-Python @('tftp_server.py','--self-test'); return }
}
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Запустите Setup.cmd от имени администратора.'}
if ($RestoreNetwork) {Restore-Cable (Get-Content -Raw $state | ConvertFrom-Json); return}
if (Test-Path $state) {throw 'Сначала восстановите адаптер командой Setup.cmd -RestoreNetwork.'}
Write-Host 'Соедините только один TL-MR3020 EU v3.30 напрямую кабелем с отдельным Ethernet-адаптером. Отключите Wi-Fi/VPN с пересекающейся подсетью.'
$adapters=@(Get-NetAdapter -Physical | Where-Object MediaType -eq '802.3')
$adapters | Format-Table ifIndex,Name,InterfaceDescription,Status
$index=[int](Read-Host 'Введите ifIndex выделенного Ethernet-адаптера')
$adapter=$adapters | Where-Object ifIndex -eq $index
if (!$adapter) {throw 'Нужен физический Ethernet-адаптер.'}
$ipv4=Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $index
if ($ipv4.Dhcp -ne 'Enabled' -or (Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object PrefixOrigin -eq 'Manual')) {throw 'Для мастера нужен отдельный адаптер с автоматическим IPv4 без ручных адресов.'}
if (!$InstallOnly) {
    if (Get-NetUDPEndpoint -LocalPort 69,1069 -ErrorAction SilentlyContinue) {throw 'UDP 69 или 1069 занят. Закройте другой TFTP-сервер.'}
    if (Get-NetRoute -DestinationPrefix '192.168.1.0/24' -ErrorAction SilentlyContinue | Where-Object InterfaceIndex -ne $index) {throw 'Освободите сеть 192.168.1.0/24 перед прошивкой.'}
    Write-Host 'Прошивка заменит заводскую ОС и настройки. Проверьте регион и ревизию на наклейке.'
    if ((Read-Host 'Для подтверждения введите MR3020 EU V3.30') -cne 'MR3020 EU V3.30') {throw 'Отменено'}
}
$saved=@{guid=[string]$adapter.InterfaceGuid;rule=('SchoolbellTFTP-'+[guid]::NewGuid().ToString())}
New-Item -ItemType Directory -Force $stateDir | Out-Null
$saved | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath $state
try {
    if (!$InstallOnly) {
        Set-CableIP $index '192.168.0.225'
        New-NetFirewallRule -Name $saved.rule -DisplayName 'Schoolbell temporary TFTP' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 69,1069 -LocalAddress 192.168.0.225 -RemoteAddress 192.168.0.2 -InterfaceAlias $adapter.Name -Program $python | Out-Null
        Write-Host 'Дождитесь READY, затем зажмите Reset и подайте питание. После начала передачи отпустите кнопку. Не прерывайте питание во время записи.'
        Run-Python @('tftp_server.py')
        Remove-NetFirewallRule -Name $saved.rule
        Write-Host 'Файл передан. Ожидаем самостоятельной перезагрузки в OpenWrt.'
        Remove-NetIPAddress -InterfaceIndex $index -IPAddress 192.168.0.225 -Confirm:$false
    }
    Set-CableIP $index '192.168.1.2'
    $ready=$false
    for ($i=0;$i -lt 120;$i++) {
        $client=New-Object System.Net.Sockets.TcpClient
        try {
            $client.Client.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Parse('192.168.1.2'),0))
            $task=$client.ConnectAsync('192.168.1.1',22)
            if ($task.Wait(1000) -and $client.Connected) {$ready=$true;break}
        } catch {} finally {$client.Close()}
        Start-Sleep -Seconds 2
    }
    if (!$ready) {throw 'SSH не появился. Проверьте загрузку. После загрузки OpenWrt повторите с -InstallOnly, без Reset.'}
    Run-Python @('install.py')
    Write-Host 'Готово. После восстановления DHCP откройте http://192.168.1.1/cgi-bin/luci/admin/schoolbell'
} finally {Restore-Cable $saved}
