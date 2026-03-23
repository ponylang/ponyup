$version = "3.9.1"

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($arch -ieq "X64") { $zipArch = "x64" }
elseif ($arch -ieq "Arm64") { $zipArch = "ARM64" }
else { throw "Unsupported architecture: $arch" }

$zipName = "libressl_v${version}_windows_${zipArch}.zip"
$url = "https://github.com/libressl/portable/releases/download/v${version}/${zipName}"

$tempDir = Join-Path $env:TEMP "libressl"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Invoke-WebRequest $url -OutFile "$tempDir\$zipName"
Expand-Archive -Force -Path "$tempDir\$zipName" -DestinationPath "$tempDir\libressl"

$repoRoot = Split-Path $PSScriptRoot
Copy-Item -Force "$tempDir\libressl\lib\ssl.lib" "$repoRoot\ssl.lib"
Copy-Item -Force "$tempDir\libressl\lib\crypto.lib" "$repoRoot\crypto.lib"
Copy-Item -Force "$tempDir\libressl\lib\tls.lib" "$repoRoot\tls.lib"
