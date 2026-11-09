#requires -Version 5.1
# Local preparation only: no adapter/device access, no administrator required.
$ErrorActionPreference='Stop'
$archive=Join-Path $PSScriptRoot 'vendor/python-3.11.9-embed-amd64.zip'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b') {throw 'Embedded Python hash mismatch'}
$runtime=Join-Path $PSScriptRoot 'dist/bootstrap-python'
Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
& (Join-Path $runtime 'python.exe') -c "import runpy,sys; sys.path.insert(0,sys.argv[1]); path=sys.argv[1]+'/build_recovery.py'; sys.argv=[path]; runpy.run_path(path,run_name='__main__')" $PSScriptRoot
if ($LASTEXITCODE -ne 0) {throw 'Recovery kit build failed'}
