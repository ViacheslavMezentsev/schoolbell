# Read-only local inventory. No probes, lease renewals or configuration commands.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$adapters=@(Get-NetAdapter -IncludeHidden)
$ipInterfaces=@(Get-NetIPInterface -AddressFamily IPv4)
$addresses=@(Get-NetIPAddress -AddressFamily IPv4)
$routes=@(Get-NetRoute -AddressFamily IPv4)
$ports=@(Get-NetUDPEndpoint)
$devices=@(Get-CimInstance Win32_NetworkAdapter)
$rows=@(foreach($a in $adapters) {
 if (!$a.InterfaceGuid) {continue}
 $ipv4=@($ipInterfaces | Where-Object InterfaceIndex -eq $a.ifIndex)
 $device=@($devices | Where-Object InterfaceIndex -eq $a.ifIndex)
 if ($ipv4.Count -gt 1 -or $device.Count -gt 1) {throw 'Ambiguous adapter inventory'}
 $ips=@(foreach($ip in @($addresses | Where-Object InterfaceIndex -eq $a.ifIndex)) {
  $origin=switch ([string]$ip.PrefixOrigin) {'Dhcp' {'dhcp'} 'Manual' {'manual'} 'WellKnown' {'well-known'} default {throw 'Unknown IPv4 origin'}}
  @{ip=[string]$ip.IPAddress;origin=$origin}
 })
 @{guid=[string]$a.InterfaceGuid;index=[int]$a.ifIndex;name=[string]$a.Name;description=[string]$a.InterfaceDescription;
 physical=[bool]$a.HardwareInterface;usb=[bool]($device.Count -eq 1 -and $device[0].PNPDeviceID -like 'USB\*');
 dhcp=[bool]($ipv4.Count -eq 1 -and $ipv4[0].Dhcp -eq 'Enabled');link_up=[bool]($a.Status -eq 'Up');
 media=$(if ([string]$a.MediaType -eq '802.3') {'ethernet'} else {'other'});addresses=$ips}
})
# Preserve interfaces absent from Get-NetAdapter (e.g. loopback) for address collision checks.
foreach($index in @($addresses.InterfaceIndex | Sort-Object -Unique)) {
 if ($rows.index -contains $index) {continue}
 if (@($addresses | Where-Object { $_.InterfaceIndex -eq $index -and $_.IPAddress -in @('192.168.0.225','192.168.0.2','192.168.1.1','192.168.1.2') }).Count) {throw 'Reserved address on an unenumerated interface'}
}
$state=Join-Path $env:LOCALAPPDATA 'SchoolbellSetup/network.json'
@{schema=1;pending_restore=[bool]((Test-Path -LiteralPath $state) -or (Test-Path -LiteralPath (Join-Path $env:ProgramData 'SchoolbellNetworkHelper-v1/network.json')));adapters=$rows;
 routes=@($routes | ForEach-Object {@{prefix=[string]$_.DestinationPrefix;next_hop=[string]$_.NextHop;index=[int]$_.InterfaceIndex}});
 udp_ports=@($ports.LocalPort | Sort-Object -Unique)} | ConvertTo-Json -Depth 8 -Compress
