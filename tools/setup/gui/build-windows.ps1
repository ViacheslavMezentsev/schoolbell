param([string]$MsysRoot = 'C:\msys64')
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
 $dlls | Set-Content (Join-Path $out 'imports.txt')
 Get-FileHash (Join-Path $out 'router-setup.exe') -Algorithm SHA256
 Write-Host "Built: $out\router-setup.exe"
} finally { $env:PATH = $oldPath }
