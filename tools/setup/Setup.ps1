#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly,[switch]$InstallOnly,[switch]$RestoreNetwork,[switch]$RestoreFactory,[switch]$DryRun,[int]$InterfaceIndex=0)
$ErrorActionPreference='Stop'
if (($DryRun -and ($CheckOnly -or $RestoreNetwork)) -or ($RestoreFactory -and ($InstallOnly -or $RestoreNetwork)) -or ($CheckOnly -and $RestoreNetwork) -or ($InstallOnly -and $RestoreNetwork)) {throw 'Несовместимые режимы запуска.'}
$profile=if ($RestoreFactory) {'factory'} else {'openwrt'}
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
    Run-Python @('tftp_server.py','--profile',$profile,'--check')
    if (!$RestoreFactory) {
        Get-Command ssh.exe -ErrorAction Stop | Out-Null
        Run-Python @('install.py','--check')
    }
    if ($CheckOnly) { Run-Python @('tftp_server.py','--self-test'); return }
}
if ($RestoreNetwork) {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Запустите от имени администратора.'}
    Restore-Cable (Get-Content -Raw $state | ConvertFrom-Json); return
}
Write-Host 'Соедините только один TL-MR3020 EU v3.30 напрямую кабелем с отдельным Ethernet-адаптером. Отключите Wi-Fi/VPN с пересекающейся подсетью.'
$adapters=@(Get-NetAdapter -Physical | Where-Object MediaType -eq '802.3')
$adapters | Format-Table ifIndex,Name,InterfaceDescription,Status
$index=$InterfaceIndex
if ($index -eq 0) {$index=[int](Read-Host 'Введите ifIndex выделенного Ethernet-адаптера')}
$adapter=$adapters | Where-Object ifIndex -eq $index
if (!$adapter) {throw 'Нужен физический Ethernet-адаптер.'}
$blockers=New-Object 'System.Collections.Generic.List[string]'
if (Test-Path $state) {$blockers.Add('Осталось состояние предыдущего запуска: используйте -RestoreNetwork.')}
$ipv4=Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $index
if ($ipv4.Dhcp -ne 'Enabled' -or (Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object PrefixOrigin -eq 'Manual')) {$blockers.Add('Нужен отдельный адаптер с DHCP без ручных адресов.')}
if ($adapter.Status -ne 'Up') {$blockers.Add('Ethernet link не поднят; проверьте кабель/питание перед запуском.')}
# Include more-specific routes (e.g. VPN /32), not only exact /24 prefixes.
function Contains-Address([string]$Prefix,[string]$Address) {
    $parts=$Prefix.Split('/'); $bits=[int]$parts[1]
    if ($bits -eq 0) {return $false}
    $network=[Net.IPAddress]::Parse($parts[0]).GetAddressBytes()
    $target=[Net.IPAddress]::Parse($Address).GetAddressBytes()
    for ($n=0;$n -lt 4;$n++) {
        $count=[Math]::Min(8,[Math]::Max(0,$bits-8*$n))
        $mask=256-[Math]::Pow(2,8-$count)
        if (($network[$n] -band [int]$mask) -ne ($target[$n] -band [int]$mask)) {return $false}
    }
    return $true
}
$targets=if ($InstallOnly) {@('192.168.1.1','192.168.1.2')} else {@('192.168.0.2','192.168.0.225','192.168.1.1','192.168.1.2')}
foreach ($route in Get-NetRoute -AddressFamily IPv4) {
    if ($route.InterfaceIndex -eq $index) {continue}
    foreach ($target in $targets) {
        if (Contains-Address $route.DestinationPrefix $target) {
            $blockers.Add("Пересекающийся маршрут $($route.DestinationPrefix) на интерфейсе $($route.InterfaceIndex).")
            break
        }
    }
}
if (!$InstallOnly -and (Get-NetUDPEndpoint -LocalPort 69,1069 -ErrorAction SilentlyContinue)) {$blockers.Add('UDP 69 или 1069 занят.')}
Write-Host "ПЛАН: профиль=$profile; InstallOnly=$InstallOnly; адаптер=$($adapter.Name); ifIndex=$index; GUID=$($adapter.InterfaceGuid)"
if (!$InstallOnly) {
    $image=if ($RestoreFactory) {'firmware/oem-recovery.bin'} else {'firmware/tp_recovery.bin'}
    Write-Host "Образ: $image; SHA256=$((Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash)"
    Write-Host "1. Сохранить состояние в $state. Временно добавить 192.168.0.225/24."
    Write-Host '2. Временное правило firewall: только выбранный адаптер, UDP69/1069, локально 192.168.0.225, клиент 192.168.0.2.'
    Write-Host "3. После подтверждения модели: TFTP ($profile), Reset при подаче питания; одна передача, без автоматического повтора."
    Write-Host "Журнал передачи: $PSScriptRoot/tftp-$profile.log"
}
if ($RestoreFactory) {
    Write-Host '4. Дождаться OEM-загрузки. Проверить TP-Link TL-MR3020 / Build250625 в браузере. ACK не доказывает загрузку.'
    Write-Host 'OpenWrt и Школьник будут удалены. Прежний пароль TP-Link может сохраниться; забытый пароль требует отдельного сброса. Мастер сброс не выполняет.'
    Write-Host 'SSH, opkg и установка Школьника в этом маршруте отсутствуют.'
} else {
    Write-Host 'Следом: временный адрес 192.168.1.2/24, ожидание SSH192.168.1.1, проверка модели/OpenWrt/ABI/libc, места и установленных пакетов.'
    Write-Host 'Затем: подтверждение списка IPK, установка, проверка Школьника 5.1.100 и выключенной автоматики; ввод root-пароля владельцем.'
    Write-Host 'Состав устанавливаемых IPK определяется на устройстве только при реальном запуске.'
}
Write-Host 'Завершение/ошибка: удалить собственное правило firewall и временные адреса, вернуть выбранный адаптер на DHCP.'
if ($DryRun) {
    Write-Host 'DRY RUN: только локальные чтения и проверки. Ничего не выполнялось; Reset не нажимайте.'
    Write-Host 'Модель устройства, пароль, доступность, flash/RAM и успешная загрузка здесь не проверяются. Для реального запуска нужны права администратора.'
    if ($blockers.Count) {foreach ($problem in $blockers) {Write-Host "БЛОКИРУЕТ ЗАПУСК: $problem"}; throw 'DryRun: обнаружены блокирующие условия.'}
    Write-Host 'DRY RUN OK: локальных препятствий не обнаружено.'
    return
}
if ($blockers.Count) {throw ($blockers -join "`n")}
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Запустите Setup.cmd от имени администратора.'}
if (!$InstallOnly) {
    if ($RestoreFactory) {
        Write-Host 'Возврат TP-Link EU v3.30 Build250625 удалит OpenWrt и Школьник. Сначала сохраните резервные копии.'
        Write-Host 'Старые настройки TP-Link и пароль администратора могут сохраниться. Ключ Wi-Fi с наклейки не является паролем входа.'
        Write-Host 'Забытый пароль: отдельный сброс WPS/Reset на уже включённом роутере; после сброса задайте новый пароль. Мастер сброс не выполняет.'
        if ((Read-Host 'Для подтверждения возврата введите RESTORE FACTORY') -cne 'RESTORE FACTORY') {throw 'Отменено'}
    } else {
        Write-Host 'Прошивка заменит заводскую ОС и настройки. Проверьте регион и ревизию на наклейке.'
    }
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
        Run-Python @('tftp_server.py','--profile',$profile)
        Remove-NetFirewallRule -Name $saved.rule
        if ($RestoreFactory) {
            Write-Host 'Файл передан. Это подтверждает передачу, а не успешную загрузку заводской ОС.'
            Write-Host 'Не отключайте питание. Дождитесь завершения записи и загрузки (обычно несколько минут).'
            Write-Host 'После возврата адаптера на DHCP откройте http://192.168.1.1. Адрес может отличаться при сохранённых настройках/AP.'
            Write-Host 'Проверьте заводской интерфейс TL-MR3020 и версию 1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n.'
            Write-Host 'Используйте прежний пароль администратора. При забытом пароле выполните отдельный сброс по README.'
            Write-Host 'SSH и установка пакетов Школьника в этом режиме не выполняются.'
            return
        }
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
