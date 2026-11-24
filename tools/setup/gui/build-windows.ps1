param([string]$MsysRoot = 'C:\msys64', [string]$RecoveryImage = '')
$ErrorActionPreference = 'Stop'
$bin = Join-Path $MsysRoot 'mingw64\bin'
$qt = Join-Path $MsysRoot 'mingw64\qt6-static'
$work = Join-Path ([IO.Path]::GetTempPath()) ('router-gui-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $work 'source'
$build = Join-Path $work 'build'
New-Item -ItemType Directory -Path $source -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\*" -Destination $source -Recurse
$oldPath = $env:PATH
try {
 $env:PATH = "$bin;$oldPath"
 & "$bin\cmake.exe" -S $source -B $build -G Ninja "-DCMAKE_PREFIX_PATH=$qt" -DCMAKE_BUILD_TYPE=Release
 if ($LASTEXITCODE) { throw 'CMake configuration failed' }
 & "$bin\cmake.exe" --build $build -j 4
 if ($LASTEXITCODE) { throw 'Build failed' }
 & (Join-Path $build 'test-session-proof.exe')
 if ($LASTEXITCODE) { throw 'Session proof tests failed' }
 $exe = Join-Path $build 'schoolbell-setup-wizard.exe'
 & "$bin\strip.exe" $exe
 if ($LASTEXITCODE) { throw 'Strip failed' }
 $imports = & "$bin\objdump.exe" -p $exe
 if ($LASTEXITCODE) { throw 'Import inspection failed' }
 $dlls = @($imports | Select-String 'DLL Name:' | ForEach-Object { ($_.Line -split 'DLL Name:')[1].Trim() })
 $external = @($dlls | Where-Object { $_ -notmatch "^(api-ms-win-|ext-ms-win-)" -and -not (Test-Path (Join-Path "$env:WINDIR\System32" $_)) })
 if ($external.Count) { throw "Non-system DLL dependencies: $($external -join ', ')" }
 $repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
 $out = Join-Path $repo 'out\setup-gui-external'
 New-Item -ItemType Directory -Path $out -Force | Out-Null
 Copy-Item $exe (Join-Path $out 'schoolbell-setup-wizard.exe') -Force
 # Real package pilot: interpreter and immutable local payload travel beside the EXE.
 $runtime = Join-Path $PSScriptRoot '..\vendor\python-3.11.9-embed-amd64.zip'
 if ((Get-FileHash $runtime -Algorithm SHA256).Hash.ToLower() -ne '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b') {throw 'Python archive checksum mismatch'}
 Expand-Archive -LiteralPath $runtime -DestinationPath (Join-Path $out 'python') -Force
 Copy-Item (Join-Path $PSScriptRoot 'package_worker.py') $out -Force
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

 $dlls | Set-Content (Join-Path $out 'imports.txt')
 Get-FileHash (Join-Path $out 'schoolbell-setup-wizard.exe') -Algorithm SHA256
 Write-Host "Built: $out\schoolbell-setup-wizard.exe"
} finally { $env:PATH = $oldPath }
