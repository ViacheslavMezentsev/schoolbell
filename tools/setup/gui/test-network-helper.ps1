# Local unit tests only: every network mutation cmdlet is replaced below.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'NetworkHelperCore.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('schoolbell-helper-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$path=Join-Path $root 'network.json'
$guid='11111111-1111-4111-8111-111111111111'
function Assert($ok,$message) {if (!$ok) {throw $message}}
function Reset-Test {
 $script:ips=@([pscustomobject]@{IPAddress='192.0.2.9';PrefixLength=24;AddressState='Preferred';InterfaceIndex=17;PrefixOrigin='Dhcp'})
 $script:dhcp='Enabled';$script:missing=$false;$script:badRoute=$false;$script:failAdd=$false;$script:failDhcp=$false;$script:writes=0;$script:noLease=$false;$script:renewed=0
 if (Test-Path -LiteralPath $path) {Remove-Item -LiteralPath $path}
}
function Get-NetAdapter {param([switch]$IncludeHidden)
 if (!$script:missing) {[pscustomobject]@{InterfaceGuid=$guid;ifIndex=17}}
}
function Get-NetIPAddress {param($InterfaceIndex,$AddressFamily)
 if ($InterfaceIndex -and !$script:ips.Count) {throw 'No matching IPv4 interface (injected)'}
 $script:ips
}
function Get-CimInstance {param($ClassName,$Filter) Assert ($Filter -eq 'InterfaceIndex = 17') 'renew only selected adapter';[pscustomobject]@{InterfaceIndex=17}}
function Invoke-CimMethod {param($InputObject,$MethodName,$OperationTimeoutSec,$ErrorAction)
 Assert ($InputObject.InterfaceIndex -eq 17 -and $MethodName -eq 'RenewDHCPLease') 'targeted renewal'
 $script:renewed++
 if (!$script:noLease) {$script:ips=@([pscustomobject]@{IPAddress='192.0.2.9';PrefixLength=24;AddressState='Preferred';InterfaceIndex=17;PrefixOrigin='Dhcp'})}
 [pscustomobject]@{ReturnValue=0}
}
function New-NetIPAddress {param($InterfaceIndex,$IPAddress,$PrefixLength,$PolicyStore,$ErrorAction)
 $script:writes++;if ($script:failAdd) {throw 'injected add failure'}
 $script:ips+= [pscustomobject]@{IPAddress=$IPAddress;PrefixLength=$PrefixLength;AddressState='Preferred';InterfaceIndex=17;PrefixOrigin='Manual'};$script:dhcp='Disabled'
}
function Remove-NetIPAddress {param([Parameter(ValueFromPipeline)]$InputObject,[switch]$Confirm)
 process {$script:writes++;$script:ips=@($script:ips | Where-Object IPAddress -ne $InputObject.IPAddress)}
}
function Set-NetIPInterface {param($InterfaceIndex,$AddressFamily,$Dhcp,$ErrorAction)
 $script:writes++;if ($script:failDhcp) {throw 'injected DHCP failure'};$script:dhcp=$Dhcp
}
function Get-NetIPInterface {param($InterfaceIndex,$AddressFamily) [pscustomobject]@{Dhcp=$script:dhcp}}
function Find-NetRoute {param($RemoteIPAddress,$LocalIPAddress) [pscustomobject]@{DestinationPrefix='192.168.0.0/24';InterfaceIndex=$(if($script:badRoute){99}else{17});NextHop='0.0.0.0'}}
function Start-Sleep {param($Seconds)}
function Expect-Failure($job) {$failed=$false;try {& $job | Out-Null} catch {$failed=$true};Assert $failed 'Expected failure'}
try {
 Reset-Test
 Assert ((Prepare-NetworkState $path $guid 'openwrt' {}) -eq 'configured') 'prepare'
 Assert ((Read-NetworkState $path).phase -eq 'configured') 'state'
 Assert ((Restore-NetworkState $path) -eq 'restored') 'restore'
 Assert ($script:ips.Count -eq 1 -and $script:ips[0].IPAddress -eq '192.0.2.9') 'foreign IP preserved'
 Assert (!(Test-Path $path)) 'state removed only after verification'
 Assert ((Restore-NetworkState $path) -eq 'no-state') 'repeat restore'
 Reset-Test;$script:badRoute=$true
 Expect-Failure {Prepare-NetworkState $path $guid 'factory' {}}
 Assert (!(Test-Path $path) -and $script:dhcp -eq 'Enabled' -and $script:ips.Count -eq 1) 'route failure rollback'
 Reset-Test;$script:failAdd=$true
 Expect-Failure {Prepare-NetworkState $path $guid 'openwrt' {}}
 Assert (!(Test-Path $path) -and $script:ips.Count -eq 1) 'add failure rollback'
 Reset-Test
 Expect-Failure {Prepare-NetworkState $path $guid 'openwrt' {throw 'preflight'}}
 Assert ($script:writes -eq 0 -and !(Test-Path $path)) 'preflight must precede writes'
 Reset-Test;Prepare-NetworkState $path $guid 'openwrt' {} | Out-Null;$script:missing=$true
 Expect-Failure {Restore-NetworkState $path};Assert (Test-Path $path) 'missing adapter retains state'
 $script:missing=$false;$script:failDhcp=$true
 Expect-Failure {Restore-NetworkState $path};Assert (Test-Path $path) 'DHCP failure retains state'
 $script:failDhcp=$false;Restore-NetworkState $path | Out-Null;Assert (!(Test-Path $path)) 'retry restore'
 Reset-Test
 Write-NetworkState $path @{schema=1;guid=$guid;address='192.168.0.225';prefix=24;dhcp=$true;phase='prepared'}
 $script:ips+=[pscustomobject]@{IPAddress='192.168.0.225';PrefixLength=24;AddressState='Preferred';InterfaceIndex=17;PrefixOrigin='Manual'}
 Expect-Failure {Restore-NetworkState $path};Assert ($script:writes -eq 0) 'uncertain ownership must not delete'
 Reset-Test;[IO.File]::WriteAllText($path,'{"schema":99}')
 Expect-Failure {Restore-NetworkState $path};Assert ($script:writes -eq 0) 'corrupt state must not mutate'
 Reset-Test;Prepare-NetworkState $path $guid 'openwrt' {} | Out-Null
 $script:ips=@();Restore-NetworkState $path | Out-Null
 Assert ($script:renewed -eq 1 -and !(Test-Path $path)) 'addressless interval and targeted renewal'
 Reset-Test;Prepare-NetworkState $path $guid 'openwrt' {} | Out-Null
 $script:ips=@();$script:noLease=$true
 Expect-Failure {Restore-NetworkState $path};Assert (Test-Path $path) 'missing lease retains journal'
 $script:noLease=$false;Restore-NetworkState $path | Out-Null
 Assert (!(Test-Path $path)) 'late lease retry'
 Write-Output 'PASS helper: prepare/restore, repeat, route/add/preflight failure, missing adapter, DHCP retry, uncertain ownership, corrupt state; mocked cmdlets only'
} finally {
 # Delete only this unique test directory created above.
 $resolved=[IO.Path]::GetFullPath($root)
 $boundary=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if (!$resolved.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'schoolbell-helper-test-*') {throw 'Unsafe test cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
