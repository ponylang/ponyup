$ErrorActionPreference = "Stop"

$testDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
$prefix = Join-Path $testDir 'ponyup'
$old = 'ponyup-release-0.0.1-x86_64-windows'
$other = 'corral-release-0.0.1-x86_64-windows'
$null = New-Item -ItemType Directory -Path "$prefix\$old\bin", "$prefix\$other\bin" -Force
$null = New-Item -ItemType Directory -Path "$prefix\bin" -Force
Copy-Item "$env:WINDIR\System32\whoami.exe" "$prefix\bin\ponyup.exe"
Set-Content -Path "$prefix\.lock" -Value "$old *", "$other *"
.\ponyup-init.ps1 -Prefix $prefix -SetPath $false
& "$prefix\bin\ponyup.bat" version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
.\ponyup-init.ps1 -Repository nightlies -Prefix $prefix -SetPath $false
$lock = Get-Content "$prefix\.lock"
if (($lock -notcontains $old) -or ($lock -notcontains "$other *") -or
    -not ($lock -match '^ponyup-nightly-[0-9]{8}-[^ ]+ \*$')) { throw 'Incorrect bootstrap lockfile' }
$env:PATH = "$prefix\bin;" + $env:PATH
if ((Get-Command ponyup).Source -ne "$prefix\bin\ponyup.bat") { throw 'Incorrect ponyup launcher' }
ponyup version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$platform = Get-Content "$prefix\.platform"
python .ci-scripts/install-pony-tools.py $platform nightly nightly
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:PATH = "C:\ponyc\bin;" + $env:PATH

.\make.ps1 -Command fetch 2>&1
.\make.ps1 -Command build 2>&1
.\make.ps1 -Command test 2>&1

.\build\release\ponyup.exe --prefix="$testDir" update ponyc nightly --api-timeout 120 --retries 3
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
.\build\release\ponyup.exe --prefix="$testDir" update corral nightly --api-timeout 120 --retries 3
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$prefix\bin\ponyc.bat" --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$prefix\bin\corral.bat" version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Remove-Item -LiteralPath $testDir -Recurse -Force
