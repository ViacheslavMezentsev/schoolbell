# Pure host tests: all network, firewall, sleep, export and transfer operations are mocks.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'NetworkHelperCore.ps1')
. (Join-Path $PSScriptRoot 'FlashHelperCore.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('schoolbell-flash-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$id='11111111-1111-4111-8111-111111111111';$guid='22222222-2222-4222-8222-222222222222'
function Assert($ok,$message){if(!$ok){throw $message}}
function Expect-Failure($job){$failed=$false;try{& $job}catch{$failed=$true};Assert $failed 'expected failure'}
function Reset-Test {
 Get-ChildItem -LiteralPath $root -File | Remove-Item
 $script:failRestore=$false;$script:failPrepare=$false;$script:rule=$false;$script:restores=0;$script:exports=0;$script:waited=0
}
function Prepare-NetworkState($path,$guid,$profile,$preflight){
 if($script:failPrepare){throw 'prepare failure'}
 Write-NetworkState $path @{schema=1;guid=$guid;phase='configured';address='192.168.0.225';prefix=24;dhcp=$true}
}
function Get-SavedAdapter($guid){[pscustomobject]@{ifIndex=17;Name='fixture-adapter'}}
function New-NetFirewallRule {param($Name,$DisplayName,$Direction,$Action,$Protocol,$LocalPort,$LocalAddress,$RemoteAddress,$InterfaceAlias,$Program,$ErrorAction)
 Assert ($InterfaceAlias -eq 'fixture-adapter' -and $LocalAddress -eq '192.168.0.225' -and $RemoteAddress -eq '192.168.0.2') 'firewall scope'
 Assert ((Read-NetworkState (Join-Path $root 'network.json')).rule -eq $Name) 'journal precedes firewall'
 $script:rule=$true
}
function Restore-NetworkState($path){$script:restores++;$script:rule=$false;if($script:failRestore){throw 'DHCP failure'};Remove-Item -LiteralPath $path}
function Start-Sleep {param($Seconds)
 if($Seconds -eq 90){
  $s=Read-FlashSession $root
  Assert ($s.phase -eq 'boot-wait' -and $s.wait_until_ms -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) 'boot countdown published before waiting'
 }
 $script:waited+=$Seconds
}
$export={param($profile,$dir);$script:exports++}
$transfer={param($profile,$dir,$op)
 $s=Read-FlashSession $dir;$s.possible_write=$true;$s.transfer_complete=$true;$s.phase='transferred';$s.acknowledged=8126464;Write-NetworkState (Join-Path $dir 'flash-session.json') $s
}
try {
 foreach($profile in @('openwrt','factory')) {
  Reset-Test;Invoke-FlashSession $root $guid $profile $id {} $export $transfer
  Assert ((Read-FlashSession $root).phase -eq 'needs-check') 'manual version check required'
  Assert ($script:waited -ge 90 -and !$script:rule -and !(Test-Path (Join-Path $root 'network.json'))) 'wait and cleanup'
  Expect-Failure {Invoke-FlashSession $root $guid $profile $id {} $export $transfer}
  Assert ($script:exports -eq 1) 'same operation cannot be replayed'
  $other='33333333-3333-4333-8333-333333333333'
  Invoke-FlashSession $root $guid $profile $other {} $export $transfer
  Assert ($script:exports -eq 2) 'completed previous session does not block new operation'
  Confirm-FlashSession $root $id $profile
  Assert ((Get-Content -Raw (Join-Path $root ('flash-'+$id+'.json')) | ConvertFrom-Json).phase -eq 'user-confirmed') 'own receipt confirmed'
  Assert ((Read-FlashSession $root).operation -eq $other -and (Read-FlashSession $root).phase -eq 'needs-check') 'other session not overwritten'
 }
 Reset-Test;$script:failPrepare=$true
 Expect-Failure {Invoke-FlashSession $root $guid 'openwrt' $id {} $export $transfer}
 Assert ((Read-FlashSession $root).phase -eq 'not-started' -and !$script:rule) 'preflight failure'
 Reset-Test
 Expect-Failure {Invoke-FlashSession $root $guid 'factory' $id {} {throw 'bad image'} $transfer}
 Assert (!(Test-Path (Join-Path $root 'network.json'))) 'bad image changes no network'
 Reset-Test;$script:failRestore=$true
 Expect-Failure {Invoke-FlashSession $root $guid 'openwrt' $id {} $export $transfer}
 Assert ($script:restores -eq 6 -and (Read-FlashSession $root).phase -eq 'recovery-required') 'bounded retries'
 Expect-Failure {Confirm-FlashSession $root $id 'openwrt'}
 Reset-Test
 $broken={param($profile,$dir,$op);$s=Read-FlashSession $dir;$s.possible_write=$true;$s.phase='unknown';Write-NetworkState (Join-Path $dir 'flash-session.json') $s;throw 'broken transfer'}
 Expect-Failure {Invoke-FlashSession $root $guid 'openwrt' $id {} $export $broken}
 Assert ((Read-FlashSession $root).phase -eq 'unknown' -and $script:waited -ge 90 -and $script:restores -eq 1) 'unknown outcome still waits and restores'
 Write-Output 'PASS flash helper: both profiles, manual check, repeat guard, image/preflight failure, DHCP retries, unknown outcome; all side effects mocked'
} finally {
 $resolved=[IO.Path]::GetFullPath($root);$boundary=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(!$resolved.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'schoolbell-flash-test-*'){throw 'Unsafe cleanup'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
