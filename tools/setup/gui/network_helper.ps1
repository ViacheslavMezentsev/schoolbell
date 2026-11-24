#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('prepare','restore')][string]$Action,
 [string]$AdapterGuid='', [ValidateSet('openwrt','factory')][string]$Profile='openwrt')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$env:PYTHONIOENCODING='utf-8'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {exit 2}
. (Join-Path $PSScriptRoot 'NetworkHelperCore.ps1')
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
 if ($Action -eq 'restore') {Restore-NetworkState $state | Out-Null;exit 0}
 $guid=([guid]$AdapterGuid).ToString()
 $preflight={param($id,$profile)
  # Fixed read-only collector + planner; never accept scripts/paths from the UI.
  $data=& (Join-Path $PSScriptRoot 'python/python.exe') (Join-Path $PSScriptRoot 'network_worker.py') --guid $id --profile $profile --model 'MR3020 EU V3.30'
  if ($LASTEXITCODE -ne 0) {throw 'Preflight failed'}
  $result=($data -join "`n") | ConvertFrom-Json
  if ($result.plan.eligible -ne $true -or [guid]$result.plan.adapter.guid -ne [guid]$id) {throw 'Network preflight blocked'}
 }
 Prepare-NetworkState $state $guid $Profile $preflight | Out-Null
 exit 0
} catch {exit 3}
finally {if ($held) {$mutex.ReleaseMutex()};$mutex.Dispose()}
