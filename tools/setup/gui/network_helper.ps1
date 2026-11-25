#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('prepare','restore','flash','confirm')][string]$Action,
 [string]$AdapterGuid='', [ValidateSet('openwrt','factory')][string]$Profile='openwrt', [string]$Operation='')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$env:PYTHONIOENCODING='utf-8'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {exit 2}
. (Join-Path $PSScriptRoot 'NetworkHelperCore.ps1')
. (Join-Path $PSScriptRoot 'FlashHelperCore.ps1')
$mutex=[Threading.Mutex]::new($false,'Global\SchoolbellNetworkHelperV1')
$held=$false
try {
 try {$held=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$held=$true}
 if (!$held) {exit 4}
 $root=Join-Path $env:ProgramData 'SchoolbellNetworkHelper-v1'
 if (!(Test-Path -LiteralPath $root)) {
  New-Item -ItemType Directory -Path $root | Out-Null
  $acl=[Security.AccessControl.DirectorySecurity]::new()
  $acl.SetAccessRuleProtection($true,$false)
  foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
   $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
  }
  $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow'))
  $acl.SetOwner([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
  Set-Acl -LiteralPath $root -AclObject $acl
 }
 if ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Reparse state directory'}
 $acl=Get-Acl -LiteralPath $root
 if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin @('S-1-5-18','S-1-5-32-544')) {throw 'Untrusted state owner'}
 foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
  if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544') -and ($rule.FileSystemRights -band ([Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership))) {throw 'Writable state directory'}
 }
 $state=Join-Path $root 'network.json'
 if ($Action -eq 'restore') {
  Restore-NetworkState $state | Out-Null
  $previous=Read-FlashSession $root
  if ($previous -and $previous.possible_write -and $previous.phase -ne 'user-confirmed') {
   $previous.phase=if ($previous.transfer_complete) {'needs-check'} else {'unknown'}
   Write-NetworkState (Join-Path $root 'flash-session.json') $previous
  }
  exit 0
 }
 if ($Action -eq 'confirm') {Confirm-FlashSession $root ([guid]$Operation).ToString() $Profile;exit 0}
 $guid=([guid]$AdapterGuid).ToString()
 $preflight={param($id,$profile)
  # Fixed read-only collector + planner; never accept scripts/paths from the UI.
  $data=& (Join-Path $PSScriptRoot 'python/python.exe') (Join-Path $PSScriptRoot 'network_worker.py') --guid $id --profile $profile --model 'MR3020 EU V3.30'
  if ($LASTEXITCODE -ne 0) {throw 'Preflight failed'}
  $result=($data -join "`n") | ConvertFrom-Json
  if ($result.plan.eligible -ne $true -or [guid]$result.plan.adapter.guid -ne [guid]$id) {throw 'Network preflight blocked'}
 }
 if ($Action -eq 'flash') {
  Add-Type -Path (Join-Path $PSScriptRoot 'HelperJob.cs')
  [SchoolbellHelperJob]::Attach()
  $operationId=([guid]$Operation).ToString()
  if ([guid]$operationId -eq [guid]::Empty) {throw 'Invalid operation'}
  $export={param($profile,$dir)
   $exportProcess=Start-Process -FilePath (Join-Path $PSScriptRoot 'schoolbell-setup-wizard.exe') -ArgumentList @('--export-firmware',$profile,('"'+$dir+'"')) -WindowStyle Hidden -PassThru -Wait
   if ($exportProcess.ExitCode -ne 0) {throw 'Embedded image export failed'}
   $expected=if ($profile -eq 'openwrt') {'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'} else {'2b0d85b1c7f5e6c65930e117ada0afe60a29a35882ecac65610191876b6b0665'}
   if ((Get-FileHash (Join-Path $dir ($profile+'.bin')) -Algorithm SHA256).Hash.ToLower() -ne $expected) {throw 'Embedded image hash mismatch'}
  }
  $transfer={param($profile,$dir,$id)
   if (Test-Path -LiteralPath (Join-Path $PSScriptRoot ('flash-stop-'+$id+'.request'))) {throw 'Transfer cancelled before start'}
   & (Join-Path $PSScriptRoot 'python/python.exe') (Join-Path $PSScriptRoot 'flash_worker.py') --profile $profile --root $dir --operation $id
   if ($LASTEXITCODE -ne 0) {throw 'Transfer incomplete; inspect router before retry'}
  }
  Invoke-FlashSession $root $guid $Profile $operationId $preflight $export $transfer
 } else {Prepare-NetworkState $state $guid $Profile $preflight | Out-Null}
 exit 0
} catch {exit 3}
finally {if ($held) {$mutex.ReleaseMutex()};$mutex.Dispose()}
