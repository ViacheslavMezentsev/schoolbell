# Windows-only launcher tests. The fixture never accesses devices or the network.
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('schoolbell-launcher space & test-'+[guid]::NewGuid())
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $repo 'tools/setup/Setup.cmd') -Destination $testRoot
    $probe=@'
param([switch]$CheckOnly,[switch]$DryRun,[switch]$RestoreFactory,[int]$InterfaceIndex=0)
@{version=$PSVersionTable.PSVersion.ToString();check=[bool]$CheckOnly;dry=[bool]$DryRun;factory=[bool]$RestoreFactory;index=$InterfaceIndex;root=$PSScriptRoot} | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'result.json')
exit 37
'@
    [IO.File]::WriteAllText((Join-Path $testRoot 'Setup.ps1'),$probe)
    $pwsh7=Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
    if (!(Test-Path $pwsh7)) {throw 'This test requires installed PowerShell 7'}
    foreach ($mode in 'standard','path','legacy') {
        foreach ($case in @(@('-CheckOnly', $true,$false,$false,0),@('-DryRun -InterfaceIndex 42',$false,$true,$false,42),@('-RestoreFactory -DryRun -InterfaceIndex 43',$false,$true,$true,43))) {
            $result=Join-Path $testRoot 'result.json'
            if (Test-Path $result) {Remove-Item -LiteralPath $result}
            $pi=[Diagnostics.ProcessStartInfo]::new()
            $pi.FileName=Join-Path $env:SystemRoot 'System32/cmd.exe'
            $pi.Arguments='/d /c ""'+(Join-Path $testRoot 'Setup.cmd')+'" '+$case[0]+' <nul"'
            $pi.WorkingDirectory=$env:SystemRoot
            $pi.UseShellExecute=$false;$pi.CreateNoWindow=$true
            $pi.RedirectStandardOutput=$true;$pi.RedirectStandardError=$true
            if ($mode -ne 'standard') {
                $pi.EnvironmentVariables['ProgramFiles']=Join-Path $testRoot 'absent'
                $pi.EnvironmentVariables['ProgramW6432']=Join-Path $testRoot 'absent'
                $pi.EnvironmentVariables['PATH']=Join-Path $env:SystemRoot 'System32'
                if ($mode -eq 'path') {$pi.EnvironmentVariables['PATH']+=';'+(Split-Path $pwsh7)}
            }
            $proc=[Diagnostics.Process]::Start($pi)
            $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync()
            if (!$proc.WaitForExit(30000)) {$proc.Kill();throw 'Launcher timed out'}
            if ($proc.ExitCode -ne 37) {throw "Exit code lost: $($proc.ExitCode): $($stdout.Result) $($stderr.Result)"}
            $r=Get-Content -Raw -LiteralPath $result | ConvertFrom-Json
            $expectedMajor=if ($mode -eq 'legacy') {5} else {7}
            if (([version]$r.version).Major -ne $expectedMajor -or $r.check -ne $case[1] -or $r.dry -ne $case[2] -or $r.factory -ne $case[3] -or $r.index -ne $case[4] -or $r.root -ne $testRoot) {throw "Wrong forwarding: $($r|ConvertTo-Json -Compress)"}
            Write-Output "PASS launcher $mode $($case[0]): PowerShell $($r.version), exit 37, path with spaces and ampersand"
        }
    }
} finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (!$resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'schoolbell-launcher space & test-*') {throw 'Unsafe test cleanup path'}
    [IO.Directory]::Delete($resolved,$true)
}
