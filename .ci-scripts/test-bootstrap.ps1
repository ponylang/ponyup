$ErrorActionPreference = "Stop"

# Install into the default prefix and keep the bin path in sync with it, so this
# stays correct if ponyup-init.ps1's default -Prefix ever changes.
$prefix = "$env:LOCALAPPDATA\ponyup"

.\ponyup-init.ps1 -Repository nightlies -Prefix $prefix -SetPath $false

$env:PATH = "$prefix\bin;" + $env:PATH

# $ErrorActionPreference = "Stop" only makes cmdlet errors terminating; a native
# command's non-zero exit aborts only under pwsh >= 7.4. Guard explicitly so a
# failed update fails the job here, not opaquely at the later build step.
ponyup update ponyc nightly --api-timeout 120 --retries 3
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
ponyup update corral nightly --api-timeout 120 --retries 3
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

.\make.ps1 -Command fetch 2>&1
.\make.ps1 -Command build 2>&1
.\make.ps1 -Command test 2>&1
