# Windows host-only control-flow tests. Network inventory is mocked; mutations fail closed.
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$source=Join-Path $repo 'tools/setup/Setup.ps1'
$tokens=$null; $parseErrors=$null
[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors) | Out-Null
if ($parseErrors.Count) {throw ($parseErrors | Out-String)}
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('schoolbell-dryrun-'+[guid]::NewGuid())
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$originalLocation=Get-Location
$originalLocal=$env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA=Join-Path $testRoot 'profile'
    [IO.Directory]::CreateDirectory((Join-Path $testRoot 'firmware')) | Out-Null
    foreach ($name in 'tp_recovery.bin','oem-recovery.bin') {[IO.File]::WriteAllText((Join-Path $testRoot "firmware/$name"),'fixture')}
    $marker=Join-Path $testRoot 'marker.txt'; [IO.File]::WriteAllText($marker,'fixture')
    [IO.File]::WriteAllText((Join-Path $testRoot 'SHA256SUMS'),((Get-FileHash $marker).Hash.ToLower()+'  marker.txt'))
    $script=[IO.File]::ReadAllText($source)
    # Replace only the external Python process, keeping the actual orchestration intact.
    if (-not $script.Contains('& $python @Arguments')) {throw 'Python spy injection point changed'}
    $script=$script.Replace('& $python @Arguments','Invoke-TestPython $Arguments')
    $scriptPath=Join-Path $testRoot 'Setup.ps1';[IO.File]::WriteAllText($scriptPath,$script,[Text.UTF8Encoding]::new($true))
    function Invoke-TestPython($Arguments) {
        $call=$Arguments -join ' '
        $global:setupTestCalls.Add($call)
        if ($call -notmatch ' --check$' -and $call -ne 'tftp_server.py --self-test') {throw "UNSAFE external call: $call"}
        if ($global:setupTestBadImage -and $call -match 'factory') {throw 'Damaged OEM image'}
        $global:LASTEXITCODE=0
    }
    function Get-NetAdapter { [pscustomobject]@{ifIndex=42;Name='Fixture Ethernet';InterfaceGuid='11111111-1111-1111-1111-111111111111';MediaType='802.3';Status='Up'} }
    function Get-NetIPInterface { [pscustomobject]@{Dhcp=$(if ($global:setupTestManual) {'Disabled'} else {'Enabled'})} }
    function Get-NetIPAddress { if ($global:setupTestManual) {[pscustomobject]@{PrefixOrigin='Manual'}} }
    function Get-NetRoute {
        [pscustomobject]@{DestinationPrefix='0.0.0.0/0';InterfaceIndex=7}
        if ($global:setupTestConflict) {[pscustomobject]@{DestinationPrefix='192.168.1.1/32';InterfaceIndex=7}}
    }
    function Get-NetUDPEndpoint {if ($global:setupTestOccupied) {[pscustomobject]@{LocalPort=69}}}
    function Read-Host {throw 'Unexpected interactive prompt'}
    function New-NetIPAddress {throw 'NETWORK MUTATION'}
    function Remove-NetIPAddress {throw 'NETWORK MUTATION'}
    function Set-NetIPInterface {throw 'NETWORK MUTATION'}
    function New-NetFirewallRule {throw 'FIREWALL MUTATION'}
    function Remove-NetFirewallRule {throw 'FIREWALL MUTATION'}
    function New-Item {throw 'STATE WRITE'}
    function Set-Content {throw 'STATE WRITE'}
    function Start-Sleep {throw 'Unexpected wait'}
    function ssh.exe {throw 'DEVICE ACCESS'}
    $global:setupTestBadImage=$false;$global:setupTestManual=$false;$global:setupTestConflict=$false;$global:setupTestOccupied=$false
    foreach ($factory in $false,$true) {
        $global:setupTestCalls=New-Object 'System.Collections.Generic.List[string]'
        $text=(& $scriptPath -DryRun -RestoreFactory:$factory -InterfaceIndex 42 6>&1 | Out-String)
        if ($text -notmatch 'DRY RUN OK') {throw 'Missing successful dry run'}
        if ($factory -and (($global:setupTestCalls -join ';') -match 'install.py')) {throw 'Factory route called installer'}
        if (!$factory -and -not $global:setupTestCalls.Contains('install.py --check')) {throw 'Missing package validation'}
        if (($global:setupTestCalls -join ';') -match 'self-test') {throw 'DryRun unexpectedly opens loopback sockets'}
        if (Test-Path (Join-Path $env:LOCALAPPDATA 'SchoolbellSetup')) {throw 'DryRun created state'}
        Write-Output "PASS DryRun factory=$factory"
    }
    foreach ($failure in 'manual','conflict','occupied','badImage') {
        Set-Variable -Scope Global -Name ('setupTest'+$failure) -Value $true
        $global:setupTestCalls=New-Object 'System.Collections.Generic.List[string]';$failed=$false
        try { & $scriptPath -DryRun -RestoreFactory -InterfaceIndex 42 6>$null } catch {
            $expected=if ($failure -eq 'badImage') {'Damaged OEM image'} else {'DryRun: обнаружены блокирующие условия.'}
            if ($_.Exception.Message -ne $expected) {throw}
            $failed=$true
        }
        if (!$failed) {throw "Missed blocker $failure"}
        Set-Variable -Scope Global -Name ('setupTest'+$failure) -Value $false
        Write-Output "PASS blocker=$failure"
    }
    $failed=$false
    try {& $scriptPath -DryRun -RestoreNetwork 6>$null} catch {if ($_.Exception.Message -ne 'Несовместимые режимы запуска.') {throw}; $failed=$true}
    if (!$failed) {throw 'Conflicting modes accepted'}
    Write-Output 'PASS conflicting modes; no network/device operations executed'
} finally {
    Set-Location $originalLocation
    $env:LOCALAPPDATA=$originalLocal
    $resolved=[IO.Path]::GetFullPath($testRoot)
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'schoolbell-dryrun-*') {throw 'Unsafe fixture cleanup target'}
    [IO.Directory]::Delete($resolved,$true)
}
