# Called under the shared elevated mutex and protected state-directory ACL.
function Read-FlashSession($Root) {
 $path=Join-Path $Root 'flash-session.json'
 if (!(Test-Path -LiteralPath $path)) {return $null}
 if ((Get-Item -LiteralPath $path).Length -gt 8192) {throw 'Invalid flash receipt'}
 $s=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
 if ($s.schema -ne 1 -or $s.profile -notin @('openwrt','factory') -or [guid]$s.operation -eq [guid]::Empty -or $s.phase -notin @('preparing','ready','transferring','transferred','not-started','unknown','boot-wait','restoring','needs-check','recovery-required','user-confirmed')) {throw 'Invalid flash receipt'}
 if ($s.possible_write -isnot [bool] -or $s.transfer_complete -isnot [bool] -or $s.acknowledged -isnot [long] -and $s.acknowledged -isnot [int] -or $s.acknowledged -lt 0 -or $s.acknowledged -gt 8126464) {throw 'Invalid flash progress fields'}
 return $s
}
function Confirm-FlashSession($Root,$Operation,$Profile) {
 $s=Read-FlashSession $Root
 if (!$s -or $s.operation -ne $Operation -or $s.profile -ne $Profile -or !$s.possible_write -or $s.phase -notin @('needs-check','unknown','recovery-required') -or (Test-Path (Join-Path $Root 'network.json'))) {throw 'Cannot confirm this flash session'}
 $s.phase='user-confirmed'
 Write-NetworkState (Join-Path $Root 'flash-session.json') $s
}
function Invoke-FlashSession($Root,$Guid,$Profile,$Operation,$Preflight,$Export,$Transfer) {
 $path=Join-Path $Root 'flash-session.json';$network=Join-Path $Root 'network.json'
 $old=Read-FlashSession $Root
 if ($old -and $old.possible_write -and $old.phase -ne 'user-confirmed' -and !($old.phase -eq 'unknown' -and !$old.transfer_complete)) {throw 'Inspect router and confirm result before another transfer'}
 if (Test-Path -LiteralPath $network) {throw 'Restore network first'}
 if ($old) {
  $history=Join-Path $Root ('flash-'+$old.operation+'.json')
  if (!(Test-Path -LiteralPath $history)) {Copy-Item -LiteralPath $path -Destination $history}
 }
 # Validate/extract fixed embedded bytes before touching network or state.
 & $Export $Profile $Root
 $s=@{schema=1;operation=$Operation;profile=$Profile;phase='preparing';acknowledged=0;possible_write=$false;transfer_complete=$false}
 Write-NetworkState $path $s
 $prepared=$false
 try {
  Prepare-NetworkState $network $Guid $Profile $Preflight | Out-Null
  $prepared=$true
  $adapter=Get-SavedAdapter $Guid
  $net=Read-NetworkState $network
  $rule='SchoolbellGUI-TFTP-'+$Operation
  $net | Add-Member -NotePropertyName rule -NotePropertyValue $rule
  Write-NetworkState $network $net  # Journal before firewall mutation.
  New-NetFirewallRule -Name $rule -DisplayName 'Schoolbell GUI temporary recovery' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 69,1069 -LocalAddress 192.168.0.225 -RemoteAddress 192.168.0.2 -InterfaceAlias $adapter.Name -Program (Join-Path $PSScriptRoot 'python/python.exe') -ErrorAction Stop | Out-Null
  & $Transfer $Profile $Root $Operation
 } finally {
  $current=Read-FlashSession $Root
  if ($current.possible_write) {
   $current.phase='boot-wait';Write-NetworkState $path $current
   # The final ACK precedes flash writes. Never reboot or re-send during this wait.
   Start-Sleep -Seconds 90
  }
  if ($prepared -or (Test-Path -LiteralPath $network)) {
   $current.phase='restoring';Write-NetworkState $path $current
   $restored=$false
   for ($attempt=0;$attempt -lt 6;$attempt++) {
    try {Restore-NetworkState $network | Out-Null;$restored=$true;break} catch {if ($attempt -lt 5) {Start-Sleep -Seconds 5}}
   }
   $current.phase=if (!$restored) {'recovery-required'} elseif ($current.possible_write) {if ($current.transfer_complete) {'needs-check'} else {'unknown'}} else {'not-started'}
   Write-NetworkState $path $current
   if (!$restored) {throw 'Network recovery pending; retry restoration'}
  } else {
   $current.phase='not-started';Write-NetworkState $path $current
  }
 }
}
