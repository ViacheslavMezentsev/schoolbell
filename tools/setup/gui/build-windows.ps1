param([string]$MsysRoot = 'C:\msys64', [string]$RecoveryImage = '', [ValidateSet('MINGW64','UCRT64')][string]$MsysEnvironment = 'MINGW64')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'test-network-helper.ps1')
if (!$?) {throw 'Network helper mock tests failed'}
& (Join-Path $PSScriptRoot 'test-flash-helper.ps1')
if (!$?) {throw 'Flash helper mock tests failed'}
$prefix = Join-Path $MsysRoot $MsysEnvironment.ToLowerInvariant()
$bin = Join-Path $prefix 'bin'
$qt = Join-Path $prefix 'qt6-static'
foreach ($required in @('bin/cmake.exe','bin/ninja.exe','bin/gcc.exe','bin/g++.exe','bin/strip.exe','bin/objdump.exe','qt6-static/lib/cmake/Qt6/Qt6Config.cmake')) {
 if (!(Test-Path -LiteralPath (Join-Path $prefix $required))) {throw "Missing $MsysEnvironment toolchain file: $required"}
}
Write-Host "Static Qt toolchain: $MsysEnvironment"

$work = Join-Path ([IO.Path]::GetTempPath()) ('router-gui-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $work 'source'
$build = Join-Path $work 'build'
New-Item -ItemType Directory -Path $source -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\*" -Destination $source -Recurse
$repo = (Resolve-Path "$PSScriptRoot\..\..\..").ProviderPath
$runtime = Join-Path $PSScriptRoot '..\vendor\python-3.11.9-embed-amd64.zip'
if ((Get-FileHash $runtime -Algorithm SHA256).Hash.ToLower() -ne '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b') {throw 'Python archive checksum mismatch'}
$buildPython=Join-Path $work 'python'
Expand-Archive -LiteralPath $runtime -DestinationPath $buildPython
Copy-Item (Join-Path $PSScriptRoot '../firmware.py') $work
Add-Content (Join-Path $buildPython 'python311._pth') '..'
$image=if ($RecoveryImage) {$RecoveryImage} else {Join-Path $repo 'out/setup-5.1.123-inputs/openwrt-recovery.bin'}
& (Join-Path $buildPython 'python.exe') (Join-Path $source 'prepare-firmware.py') --openwrt $image --oem (Join-Path $PSScriptRoot '../vendor/tl-mr3020-eu-v3.30-250625.zip') --out (Join-Path $source 'embedded-firmware')
if ($LASTEXITCODE) {throw 'Embedded firmware preparation failed'}
Copy-Item (Join-Path $PSScriptRoot '../vendor/photos/v3.30/tl-mr3020-3.jpg') (Join-Path $source 'embedded-firmware/reset.jpg')
$diagnostics = Join-Path $repo 'out/setup-gui-diagnostics'
New-Item -ItemType Directory -Force $diagnostics | Out-Null
$oldPath = $env:PATH
try {
 & (Join-Path $MsysRoot 'usr/bin/pacman.exe') -Q | Set-Content (Join-Path $diagnostics 'msys2-packages.txt')
 if ($LASTEXITCODE) {throw 'Cannot record installed build dependencies'}

 $env:PATH = "$bin;$oldPath"
 & "$bin\cmake.exe" -S $source -B $build -G Ninja "-DCMAKE_PREFIX_PATH=$qt;$prefix" "-DCMAKE_C_COMPILER=$bin/gcc.exe" "-DCMAKE_CXX_COMPILER=$bin/g++.exe" "-DCMAKE_MAKE_PROGRAM=$bin/ninja.exe" -DCMAKE_BUILD_TYPE=Release 2>&1 | Tee-Object -FilePath (Join-Path $diagnostics 'configure.log')
 if ($LASTEXITCODE) { throw 'CMake configuration failed' }
 & "$bin\cmake.exe" --build $build -j 4 --verbose 2>&1 | Tee-Object -FilePath (Join-Path $diagnostics 'build.log')
 if ($LASTEXITCODE) { throw 'Build failed' }
 & (Join-Path $build 'test-session-proof.exe')
 if ($LASTEXITCODE) { throw 'Session proof tests failed' }
 & (Join-Path $build 'test-operation-status.exe')
 if ($LASTEXITCODE) { throw 'Operation status tests failed' }
 & (Join-Path $build 'test-firmware-action-log.exe')
 if ($LASTEXITCODE) { throw 'Firmware action log tests failed' }
 $exe = Join-Path $build 'schoolbell-setup-wizard.exe'
 & "$bin\strip.exe" $exe
 if ($LASTEXITCODE) { throw 'Strip failed' }
 $imageCheck=Start-Process -FilePath $exe -ArgumentList '--check-firmware' -WindowStyle Hidden -Wait -PassThru
 if ($imageCheck.ExitCode -ne 0) {throw 'Embedded firmware verification failed'}
 $imports = & "$bin\objdump.exe" -p $exe
 if ($LASTEXITCODE) { throw 'Import inspection failed' }
 $dlls = @($imports | Select-String 'DLL Name:' | ForEach-Object { ($_.Line -split 'DLL Name:')[1].Trim() })
 $external = @($dlls | Where-Object { $_ -notmatch "^(api-ms-win-|ext-ms-win-)" -and -not (Test-Path (Join-Path "$env:WINDIR\System32" $_)) })
 if ($external.Count) { throw "Non-system DLL dependencies: $($external -join ', ')" }
 $repo = (Resolve-Path "$PSScriptRoot\..\..\..").ProviderPath
 $out = Join-Path $repo 'out\setup-gui-external'
 New-Item -ItemType Directory -Path $out -Force | Out-Null
 Copy-Item $exe (Join-Path $out 'schoolbell-setup-wizard.exe') -Force
 # Real package pilot: interpreter and immutable local payload travel beside the EXE.
 $runtime = Join-Path $PSScriptRoot '..\vendor\python-3.11.9-embed-amd64.zip'
 if ((Get-FileHash $runtime -Algorithm SHA256).Hash.ToLower() -ne '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b') {throw 'Python archive checksum mismatch'}
 Expand-Archive -LiteralPath $runtime -DestinationPath (Join-Path $out 'python') -Force
 foreach ($file in @('network_worker.py','network_snapshot.ps1','network_helper.ps1','NetworkHelperCore.ps1','network_elevate.py','flash_worker.py','FlashHelperCore.ps1','HelperJob.cs','worker_job.py')) {Copy-Item (Join-Path $PSScriptRoot $file) $out -Force}
 foreach ($file in @('network_plan.py','firmware.py','tftp_server.py')) {Copy-Item (Join-Path $PSScriptRoot ('../'+$file)) $out -Force}
 Copy-Item (Join-Path $PSScriptRoot 'package_worker.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'session_lock.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'operation_protocol.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'fresh_install.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'device_backup.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'zip_worker.py') $out -Force
 Copy-Item (Join-Path $PSScriptRoot 'wizard-version.txt') $out -Force
 $zipRuntime=Join-Path $out 'zip-runtime'
 New-Item -ItemType Directory -Force $zipRuntime | Out-Null
 foreach ($file in @('install.py','plan.py')) {Copy-Item (Join-Path $repo "packaging/release/$file") $zipRuntime -Force}
 Copy-Item (Join-Path $repo 'scripts/schoolbell_ipk.py') $zipRuntime -Force

 Add-Content (Join-Path $out 'python/python311._pth') '..'
 $image=if ($RecoveryImage) {$RecoveryImage} else {Join-Path $repo 'out/setup-5.1.123-inputs/openwrt-recovery.bin'}
 if ((Get-FileHash $image -Algorithm SHA256).Hash.ToLower() -ne 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa') {throw 'OpenWrt recovery checksum mismatch'}
 New-Item -ItemType Directory -Force (Join-Path $out 'firmware') | Out-Null
 Copy-Item $image (Join-Path $out 'firmware/tp_recovery.bin') -Force

 $receipt = @{msys_environment=$MsysEnvironment; version=(Get-Content (Join-Path $PSScriptRoot 'wizard-version.txt') -Raw).Trim(); exe_sha256=(Get-FileHash (Join-Path $out 'schoolbell-setup-wizard.exe') -Algorithm SHA256).Hash.ToLower(); firmware_check='passed'; system_dlls_only=$true}
 $receipt | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $out 'build-receipt.json')
 $dlls | Set-Content (Join-Path $out 'imports.txt')
 Get-FileHash (Join-Path $out 'schoolbell-setup-wizard.exe') -Algorithm SHA256
 Write-Host "Built: $out\schoolbell-setup-wizard.exe"
} finally {
 $env:PATH = $oldPath
 foreach ($relative in @('CMakeCache.txt','build.ninja','CMakeFiles/CMakeConfigureLog.yaml')) {
  $inputFile = Join-Path $build $relative
  if (Test-Path -LiteralPath $inputFile) {Copy-Item -LiteralPath $inputFile -Destination (Join-Path $diagnostics ([IO.Path]::GetFileName($relative))) -Force}
 }
}
