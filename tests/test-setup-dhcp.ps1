# Host-only DHCP recovery tests. All network/CIM operations are mocked.
$ErrorActionPreference='Stop'
$source=Join-Path (Split-Path $PSScriptRoot -Parent) 'tools/setup/Setup.ps1'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in 'Renew-CableLease','Wait-CableLease','Restore-CableLease','Restore-Cable') {
    $fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    if(!$fn){throw "Missing $name"}
    . ([scriptblock]::Create($fn.Extent.Text))
}
$state='fixture-state'
$saved=@{guid='fixture-guid';rule='fixture-rule'}
function Get-NetAdapter {if(!$script:missing){[pscustomobject]@{InterfaceGuid='fixture-guid';ifIndex=42;Name='Fixture Ethernet'}}}
function Get-NetFirewallRule {param($Name,$ErrorAction) if($Name -ne 'fixture-rule'){throw 'Wrong firewall rule'}}
function Remove-NetFirewallRule {process {if($_){throw 'Unexpected firewall removal'}}}
function Remove-NetIPAddress {param($Confirm) process {if($_){throw 'Unexpected address removal'}}}
function Set-NetIPInterface {param($InterfaceIndex,$AddressFamily,$Dhcp) if($InterfaceIndex -ne 42 -or $Dhcp -ne 'Enabled'){throw 'Wrong adapter mutation'}; $script:enabled=$true}
function Get-CimInstance {param($ClassName,$Filter) if($ClassName -ne 'Win32_NetworkAdapterConfiguration' -or $Filter -ne 'InterfaceIndex = 42'){throw 'Unscoped CIM access'}; if(!$script:missingConfig){[pscustomobject]@{Tag='selected'}}}
function Invoke-CimMethod {param($InputObject,$MethodName,$OperationTimeoutSec)
    if(!$script:enabled -or $InputObject.Tag -ne 'selected' -or $MethodName -ne 'RenewDHCPLease' -or $OperationTimeoutSec -ne 30){throw 'Invalid renewal'}
    $script:renewed=$true; $script:renewals++
    if($script:late -and $script:renewals -lt 3){throw 'Router still booting'}
    if($script:timeout){throw 'CIM timeout'}
    [pscustomobject]@{ReturnValue=$script:returnCode}
}
function Get-NetIPAddress {param($InterfaceIndex,$AddressFamily,$IPAddress,$ErrorAction)
    if($InterfaceIndex -ne 42){throw 'Wrong adapter queried'}
    if($IPAddress){return} # cleanup: already absent, supports retry
    $script:polls++
    if($script:noLease -or ($script:late -and $script:renewals -lt 3)){return}
    if($script:polls -lt 3 -or $script:apipa){[pscustomobject]@{PrefixOrigin='WellKnown';AddressState='Preferred';IPAddress='169.254.1.2'};return}
    [pscustomobject]@{PrefixOrigin=$(if($script:manual){'Manual'}else{'Dhcp'});AddressState=$(if($script:tentative){'Tentative'}else{'Preferred'});IPAddress='192.0.2.10'}
}
function Start-Sleep {param($Seconds) if($Seconds -notin 1,5){throw 'Unexpected sleep'}; $script:waits++}
function Remove-Item {param($LiteralPath) if($LiteralPath -ne $state){throw 'Wrong state removed'}; $script:removed=$true}
foreach($case in 'success','return-error','timeout','apipa','no-lease','manual','tentative','missing-adapter','missing-config','retry','late-boot') {
    $script:renewals=0;$script:late=($case -eq 'late-boot');$script:enabled=$false;$script:renewed=$false;$script:removed=$false;$script:polls=0;$script:waits=0
    $script:returnCode=0;$script:timeout=$false;$script:apipa=$false;$script:noLease=$false;$script:manual=$false;$script:tentative=$false;$script:missing=$false;$script:missingConfig=$false
    switch($case){
        'return-error' {$script:returnCode=82;$script:noLease=$true}
        'timeout' {$script:timeout=$true;$script:noLease=$true}
        'apipa' {$script:apipa=$true}
        'no-lease' {$script:noLease=$true}
        'manual' {$script:manual=$true}
        'tentative' {$script:tentative=$true}
        'missing-adapter' {$script:missing=$true}
        'missing-config' {$script:missingConfig=$true;$script:noLease=$true}
    }
    $failure=$null
    try {Restore-Cable $saved} catch {$failure=$_}
    if($case -in 'success','retry','late-boot') {
        if($failure -or !$script:removed -or !$script:renewed -or ($case -ne 'late-boot' -and $script:polls -ne 3) -or ($case -eq 'late-boot' -and $script:renewals -ne 3)){throw "Recovery failed: $case $failure"}
    } else {
        if(!$failure -or $script:removed){throw "Failure lost state: $case"}
        if($case -in 'apipa','no-lease','manual','tentative' -and $script:waits -ne 35){throw 'Wait not bounded as expected'}
    }
    Write-Output "PASS DHCP $case"
}
