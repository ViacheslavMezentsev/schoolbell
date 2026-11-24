# Functions only. Tests replace system calls; entry point owns elevation and mutex.
function Write-NetworkState($Path,$State) {
 $temp=$Path+'.tmp'
 $json=$State | ConvertTo-Json -Depth 6 -Compress
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json)
 $stream=[IO.File]::Open($temp,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try {$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)} finally {$stream.Dispose()}
 if (Test-Path -LiteralPath $Path) {[IO.File]::Move($temp,$Path,$true)} else {[IO.File]::Move($temp,$Path)}
}
function Read-NetworkState($Path) {
 if (!(Test-Path -LiteralPath $Path)) {return $null}
 $file=Get-Item -LiteralPath $Path
 if ($file.Length -gt 8192 -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Invalid network state file'}
 $s=Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
 if ($s.schema -ne 1 -or $s.address -ne '192.168.0.225' -or $s.prefix -ne 24 -or $s.dhcp -ne $true -or $s.phase -notin @('prepared','address-added','configured','restoring')) {throw 'Invalid network state'}
 $guid=[guid]$s.guid
 if ($guid -eq [guid]::Empty) {throw 'Invalid adapter GUID'}
 return $s
}
function Get-SavedAdapter($Guid) {
 $rows=@(Get-NetAdapter -IncludeHidden | Where-Object { [guid]$_.InterfaceGuid -eq [guid]$Guid })
 if ($rows.Count -ne 1) {throw 'Reconnect the original USB Ethernet adapter'}
 return $rows[0]
}
function Restore-NetworkState($Path) {
 $s=Read-NetworkState $Path
 if (!$s) {return 'no-state'}
 $adapter=Get-SavedAdapter $s.guid
 $owned=@(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object IPAddress -eq $s.address)
 if ($s.phase -eq 'prepared' -and $owned.Count) {throw 'Address ownership uncertain; manual inspection required'}
 $s.phase='restoring';Write-NetworkState $Path $s
 if ($owned | Where-Object PrefixLength -ne 24) {throw 'Owned address changed; manual inspection required'}
 foreach($ip in $owned) {$ip | Remove-NetIPAddress -Confirm:$false -ErrorAction Stop}
 Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop
 $config=@(Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4)
 if ($config.Count -ne 1 -or $config[0].Dhcp -ne 'Enabled') {throw 'DHCP restoration not confirmed'}
 if (@(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object IPAddress -eq $s.address).Count) {throw 'Temporary address remains'}
 # Configuration is restored independently from the presence of a DHCP server.
 Remove-Item -LiteralPath $Path -ErrorAction Stop
 return 'restored'
}
function Prepare-NetworkState($Path,$Guid,$Profile,$Preflight) {
 if (Test-Path -LiteralPath $Path) {throw 'Restore pending network state first'}
 if ($Profile -notin @('openwrt','factory')) {throw 'Invalid profile'}
 if ([guid]$Guid -eq [guid]::Empty) {throw 'Invalid adapter GUID'}
 & $Preflight $Guid $Profile
 $adapter=Get-SavedAdapter $Guid
 $state=@{schema=1;guid=[string]$adapter.InterfaceGuid;address='192.168.0.225';prefix=24;dhcp=$true;phase='prepared'}
 # Journal precedes all changes. On failure restoration is attempted, not assumed.
 Write-NetworkState $Path $state
 try {
  New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $state.address -PrefixLength 24 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null
  $state.phase='address-added';Write-NetworkState $Path $state
  $preferred=$false
  for($i=0;$i -lt 10;$i++) {
   $ips=@(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object IPAddress -eq $state.address)
   if ($ips.Count -eq 1 -and $ips[0].AddressState -eq 'Preferred') {$preferred=$true;break}
   if ($ips | Where-Object AddressState -eq 'Duplicate') {throw 'Duplicate recovery address'}
   Start-Sleep -Seconds 1
  }
  if (!$preferred) {throw 'Recovery address did not become preferred'}
  $route=@(Find-NetRoute -RemoteIPAddress '192.168.0.2' -LocalIPAddress $state.address | Where-Object DestinationPrefix)
  if ($route.Count -ne 1 -or $route[0].InterfaceIndex -ne $adapter.ifIndex -or $route[0].NextHop -ne '0.0.0.0') {throw 'Recovery route is not direct'}
  $state.phase='configured';Write-NetworkState $Path $state
  return 'configured'
 } catch {
  $initialError=$_.Exception.Message
  try {Restore-NetworkState $Path | Out-Null} catch {throw ('Network preparation failed; restoration remains pending: '+$initialError+' / '+$_.Exception.Message)}
  throw 'Network preparation failed; original DHCP configuration restored'
 }
}
