param([string]$MsysRoot = 'C:\msys64', [string]$FreshBundle = '', [string]$RecoveryImage = '')
$ErrorActionPreference = 'Stop'
$bin = Join-Path $MsysRoot 'mingw64\bin'
$qt = Join-Path $MsysRoot 'mingw64\qt6-static'
$work = Join-Path ([IO.Path]::GetTempPath()) ('router-gui-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $work 'source'
$build = Join-Path $work 'build'
New-Item -ItemType Directory -Path $source -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\*" -Destination $source -Recurse
$photos = Join-Path $work "vendor\photos\v3.30"
New-Item -ItemType Directory -Path $photos -Force | Out-Null
Copy-Item "$PSScriptRoot\..\vendor\photos\v3.30\tl-mr3020-3.jpg" $photos
$oldPath = $env:PATH
try {
 $env:PATH = "$bin;$oldPath"
 & "$bin\cmake.exe" -S $source -B $build -G Ninja "-DCMAKE_PREFIX_PATH=$qt" -DCMAKE_BUILD_TYPE=Release
 if ($LASTEXITCODE) { throw 'CMake configuration failed' }
 & "$bin\cmake.exe" --build $build -j 4
 if ($LASTEXITCODE) { throw 'Build failed' }
 $exe = Join-Path $build 'router-setup.exe'
 & "$bin\strip.exe" $exe
 if ($LASTEXITCODE) { throw 'Strip failed' }
 $imports = & "$bin\objdump.exe" -p $exe
 if ($LASTEXITCODE) { throw 'Import inspection failed' }
 $dlls = @($imports | Select-String 'DLL Name:' | ForEach-Object { ($_.Line -split 'DLL Name:')[1].Trim() })
 $external = @($dlls | Where-Object { $_ -notmatch "^(api-ms-win-|ext-ms-win-)" -and -not (Test-Path (Join-Path "$env:WINDIR\System32" $_)) })
 if ($external.Count) { throw "Non-system DLL dependencies: $($external -join ', ')" }
 $repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
 $out = Join-Path $repo 'out\setup-gui'
 New-Item -ItemType Directory -Path $out -Force | Out-Null
 Copy-Item $exe (Join-Path $out 'router-setup.exe') -Force
 # Real package pilot: interpreter and immutable local payload travel beside the EXE.
 $runtime = Join-Path $PSScriptRoot '..\vendor\python-3.11.9-embed-amd64.zip'
 if ((Get-FileHash $runtime -Algorithm SHA256).Hash.ToLower() -ne '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b') {throw 'Python archive checksum mismatch'}
 Expand-Archive -LiteralPath $runtime -DestinationPath (Join-Path $out 'python') -Force
 Copy-Item (Join-Path $PSScriptRoot 'package_worker.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'fresh_install.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'device_backup.py') $out -Force
 Add-Content (Join-Path $out 'python/python311._pth') '..'
 $fresh = if ($FreshBundle) {$FreshBundle} else {Join-Path $repo 'out/setup-gui-fresh-bundle'}
 if (!(Test-Path (Join-Path $fresh 'manifest.json'))) {throw 'Build out/setup-gui-fresh-bundle first; see GUI README'}
 New-Item -ItemType Directory -Force (Join-Path $out 'bundle') | Out-Null
 Copy-Item (Join-Path $fresh '*') (Join-Path $out 'bundle') -Recurse -Force
 $image=if ($RecoveryImage) {$RecoveryImage} else {Join-Path $repo 'out/setup-5.1.123-inputs/openwrt-recovery.bin'}
 if ((Get-FileHash $image -Algorithm SHA256).Hash.ToLower() -ne 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa') {throw 'OpenWrt recovery checksum mismatch'}
 New-Item -ItemType Directory -Force (Join-Path $out 'firmware') | Out-Null
 Copy-Item $image (Join-Path $out 'firmware/tp_recovery.bin') -Force

 $payload = @{}
 foreach ($entry in @(@('package','5.1.127'),@('rollback','5.1.124'))) {
  $name = "modbus-schoolbell_$($entry[1])_all.ipk"
  $ipk = if ($entry[0] -eq 'package') {Join-Path $fresh $name} else {Join-Path $repo "out\$name"}
  if ($entry[0] -eq 'rollback' -and !(Test-Path $ipk)) {$ipk=Join-Path $repo "out\setup-$($entry[1])-bundle\$name"}
  if (!(Test-Path $ipk)) {throw "Missing local package $name"}
  Copy-Item $ipk (Join-Path $out $name) -Force
  $payload[$entry[0]] = @{file=$name;version=$entry[1];sha256=(Get-FileHash $ipk -Algorithm SHA256).Hash.ToLower()}
 }
 $payload | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $out 'payload.json') -Encoding utf8
 Push-Location $out
 try {
  & (Join-Path $out 'python/python.exe') -c "import fresh_install,json,pathlib; r=pathlib.Path('.'); m=json.loads((r/'payload.json').read_text(encoding='utf-8-sig')); print('Verified fresh bundle:',len(fresh_install.load_bundle(r,m['package'])))"
  if ($LASTEXITCODE) {throw 'Fresh bundle verification failed'}
 } finally {Pop-Location}
 $dlls | Set-Content (Join-Path $out 'imports.txt')
 Get-FileHash (Join-Path $out 'router-setup.exe') -Algorithm SHA256
 Write-Host "Built: $out\router-setup.exe"
} finally { $env:PATH = $oldPath }
